.pragma library

function icon50(assetOrId) {
    if (assetOrId !== undefined && assetOrId !== null && typeof assetOrId === "object") {
        if (assetOrId.logoUrl)
            return assetOrId.logoUrl
        if (assetOrId.logo50x50)
            return assetOrId.logo50x50
        if (assetOrId.logo35x35)
            return assetOrId.logo35x35
        if (assetOrId.logo150x150)
            return assetOrId.logo150x150
        assetOrId = assetOrId.instrumentId
    }

    if (assetOrId === undefined || assetOrId === null || assetOrId === "")
        return ""

    return "https://etoro-cdn.etorostatic.com/market-avatars/"
            + String(assetOrId) + "/50x50.png"
}

function typeName(typeId) {
    switch (Number(typeId || 0)) {
    case 1: return qsTr("Currencies")
    case 2: return qsTr("Commodities")
    case 4: return qsTr("Indices")
    case 5: return qsTr("Stocks")
    case 6: return qsTr("ETFs")
    case 10: return qsTr("Crypto")
    default: return qsTr("Other")
    }
}

function numberText(value, decimals) {
    if (value === undefined || value === null || value === "")
        return "—"
    return Number(value).toLocaleString(Qt.locale(), "f", decimals)
}

function profitPercent(item) {
    var invested = Number((item && (item.invested !== undefined
                                    ? item.invested : item.investment)) || 0)
    if (invested === 0)
        return 0
    return (Number(item.netProfit || 0) / invested) * 100.0
}
