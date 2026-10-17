#!/usr/bin/env python3
"""
Reproduce DM42/DM42n Load Program over USB without using USB storage.

Use the same write sequence as Load Program:
1. Erase the entire application area.
2. Write the program body and 0xFF padding, leaving the first 16 bytes erased.
3. Write the first 16 bytes without erasing again.

The first 16 bytes contain the program header, including its validity marker.
Writing them last keeps an interrupted download from leaving a valid header
on a partial program.
"""

import logging
import shutil
import sys
from pathlib import Path
from typing import ClassVar

import usb.core
import usb.util
from pydfuutil import dfu, dfuse
from pydfuutil.dfu_util import DfuUtil, disconnect_devices, probe_devices
from pydfuutil.logger import logger
from pydfuutil.quirks import QUIRK
from tqdm import tqdm


class DmWriter:
    MODEL: ClassVar[str]
    APP_RANGE: ClassVar[tuple[int, int]]
    ALT_NAME: ClassVar[str]

    DMCP_START = 0x08000000
    DFU_INTERFACE = 0

    interface: dfu.DfuIf
    options: dfuse.RuntimeOptions

    def __init__(self, interface: dfu.DfuIf):
        self.interface = interface
        assert interface.flags & dfu.IFF.DFU, "Not in DFU mode"

        device = interface.dev
        functional = interface.func_dfu

        assert functional.bcdDFUVersion == 0x011A, "Not a DfuSe bootloader"
        assert self.transfer_size >= 16 and self.transfer_size % 16 == 0

        # pydfuutil uses mem_layout to validate page erase commands.
        interface.mem_layout = dfuse.parse_memory_layout(interface.alt_name)
        usb.util.claim_interface(device, interface.interface)
        device.set_interface_altsetting(
            interface.interface, interface.altsetting
        )
        if interface.get_status().bState == dfu.State.DFU_ERROR:
            interface.clear_status()

        self.options = dfuse.RuntimeOptions()
        self.abort_to_idle()

    @property
    def page_size(self):
        return self.interface.mem_layout.pagesize

    @property
    def transfer_size(self):
        return min(self.interface.func_dfu.wTransferSize, 2048)

    def abort_to_idle(self):
        self.interface.abort_to_idle()

    def command(self, address: int, command: dfuse.Command):
        dfuse.special_command(
            self.interface, address, command, rt_opts=self.options
        )

    def write(self, address: int, data: bytes):
        self.command(address, dfuse.Command.SET_ADDRESS)
        written = dfuse.download_chunk(
            self.interface, data, len(data), 2, rt_opts=self.options
        )
        assert written == len(data), "Incomplete DFU transfer"

    def leave(self):
        # Let pydfuutil handle USB errors from disconnecting on exit.
        self.interface.quirks |= QUIRK.DFUSE_LEAVE
        dfuse.do_leave(
            self.interface,
            dfuse.RuntimeOptions(
                address=self.DMCP_START,
                flags=dfuse.RuntimeOptions.Flags.address_present,
            ),
        )


class Dm42Writer(DmWriter):
    MODEL = "dm42"
    APP_RANGE = (0x08050000, 0x08100000)
    ALT_NAME = "@Internal Flash  /0x08000000/512*0002Kg"


class Dm42nWriter(DmWriter):
    MODEL = "dm42n"
    APP_RANGE = (0x080A0000, 0x08200000)
    ALT_NAME = "@Internal Flash   /0x08000000/256*08Kg"


def tqdm_option():
    return {
        "ncols": min(shutil.get_terminal_size().columns, 120),
        "bar_format": (
            "{desc:7}: {percentage:3.0f}%|{bar}| "
            "{n_fmt:>5}/{total_fmt:>5} "
            "[{elapsed:>8}<{remaining:>8}, {rate_fmt:>12}]"
        ),
    }


for handler in logger.handlers:
    handler.setLevel(logging.WARNING)

if len(sys.argv) != 2:
    sys.exit("Usage: flash.py PROGRAM.pgm|PROGRAM.pg5")

FIRMWARE = Path(sys.argv[1])
writers: dict[str, type[DmWriter]] = {
    ".pgm": Dm42Writer,
    ".pg5": Dm42nWriter,
}
Writer = writers.get(FIRMWARE.suffix)
assert Writer, "Unsupported program extension (use .pgm or .pg5)"

image = FIRMWARE.read_bytes()
app_start, app_end = Writer.APP_RANGE
capacity = app_end - app_start
assert 16 <= len(image) <= capacity, "Invalid program size"
image += b"\xff" * (capacity - len(image))

DfuUtil.match_iface_index = Writer.DFU_INTERFACE
DfuUtil.match_iface_alt_index = 0
DfuUtil.match_iface_alt_name = Writer.ALT_NAME

try:
    probe_devices(
        usb.core.find(find_all=True, idVendor=0x0483, idProduct=0xDF11)
    )
    interface = DfuUtil.dfu_root

    # Probing can list the same interface more than once. Require one device,
    # configuration and interface; the filters above select its memory region.
    assert interface and dfuse.multiple_alt(interface), (
        f"Expected exactly one {Writer.MODEL} in DFU mode"
    )
    writer = Writer(interface)

    # ============================== Main ==============================
    print(f"Flashing {writer.MODEL}: {FIRMWARE.name}", flush=True)

    for address in tqdm(
        range(*writer.APP_RANGE, writer.page_size),
        desc="Erasing",
        unit="page",
        **tqdm_option(),
    ):
        writer.command(address, dfuse.Command.ERASE_PAGE)

    # Leave the first 16 bytes erased until the entire body has been written.
    body = image[16:]
    with tqdm(
        total=len(body),
        desc="Writing",
        unit="B",
        unit_scale=True,
        **tqdm_option(),
    ) as progress:
        for offset in range(0, len(body), writer.transfer_size):
            end = offset + writer.transfer_size
            chunk = body[offset:end]
            writer.write(app_start + 16 + offset, chunk)
            progress.update(len(chunk))
    writer.abort_to_idle()

    print("Writing program header", flush=True)
    writer.write(app_start, image[:16])
    writer.abort_to_idle()

    writer.leave()
    print("Done.")
finally:
    disconnect_devices()
