FNR == 1 { header = "" }
(FNR == 1 && /^\/\*/), /\*\// {
    header = header $0 "\n"
    if (/\*\//) {
        if (tolower(header) !~ /copyright|license/)
            printf "%s", header
    }
    next
}
{ print }
