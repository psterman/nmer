; Simple Jxon - JSON library for AHK v2
; Minimal implementation to avoid syntax issues

; Global functions
Jxon_Load(jsonText) {
    try {
        pos := 1
        return _parseValue(jsonText, &pos)
    } catch {
        return Map()
    }
}

Jxon_Dump(obj) {
    try {
        return _dumpValue(obj)
    } catch {
        return "{}"
    }
}

; Parse value
_parseValue(s, &pos) {
    _skipWhitespace(s, &pos)

    if (pos > StrLen(s)) {
        return ""
    }

    char := SubStr(s, pos, 1)

    if (char == "{") {
        pos++
        return _parseObject(s, &pos)
    } else if (char == "[") {
        pos++
        return _parseArray(s, &pos)
    } else if (char == '"') {
        return _parseString(s, &pos)
    } else if (char == "t") {
        if (SubStr(s, pos, 4) == "true") {
            pos += 4
            return true
        }
    } else if (char == "f") {
        if (SubStr(s, pos, 5) == "false") {
            pos += 5
            return false
        }
    } else if (char == "n") {
        if (SubStr(s, pos, 4) == "null") {
            pos += 4
            return ""
        }
    } else if (InStr("0123456789-.", char)) {
        return _parseNumber(s, &pos)
    }

    return ""
}

; Parse object
_parseObject(s, &pos) {
    obj := Map()

    while (pos <= StrLen(s)) {
        _skipWhitespace(s, &pos)

        if (SubStr(s, pos, 1) == "}") {
            pos++
            break
        }

        ; Parse key
        key := _parseValue(s, &pos)
        if (!IsString(key)) {
            key := String(key)
        }

        ; Skip colon
        _skipWhitespace(s, &pos)
        if (SubStr(s, pos, 1) == ":") {
            pos++
        }

        ; Parse value
        value := _parseValue(s, &pos)
        obj[key] := value

        ; Skip comma
        _skipWhitespace(s, &pos)
        if (SubStr(s, pos, 1) == ",") {
            pos++
        } else if (SubStr(s, pos, 1) == "}") {
            pos++
            break
        }
    }

    return obj
}

; Parse array
_parseArray(s, &pos) {
    arr := []

    while (pos <= StrLen(s)) {
        _skipWhitespace(s, &pos)

        if (SubStr(s, pos, 1) == "]") {
            pos++
            break
        }

        value := _parseValue(s, &pos)
        arr.Push(value)

        _skipWhitespace(s, &pos)
        if (SubStr(s, pos, 1) == ",") {
            pos++
        } else if (SubStr(s, pos, 1) == "]") {
            pos++
            break
        }
    }

    return arr
}

; Parse string
_parseString(s, &pos) {
    pos++ ; skip opening quote
    result := ""

    while (pos <= StrLen(s)) {
        char := SubStr(s, pos, 1)
        pos++

        if (char == '"') {
            break
        } else if (char == "\\") {
            if (pos <= StrLen(s)) {
                next := SubStr(s, pos, 1)
                pos++
                switch next {
                    case '"': result .= '"'
                    case '\\': result .= '\\'
                    case 'n': result .= '`n'
                    case 'r': result .= '`r'
                    case 't': result .= '`t'
                    case 'b': result .= '`b'
                    case 'f': result .= '`f'
                    default: result .= next
                }
            }
        } else {
            result .= char
        }
    }

    return result
}

; Parse number
_parseNumber(s, &pos) {
    start := pos
    while (pos <= StrLen(s)) {
        char := SubStr(s, pos, 1)
        if (InStr("0123456789.-", char)) {
            pos++
        } else {
            break
        }
    }

    numStr := SubStr(s, start, pos - start)
    if (InStr(numStr, ".")) {
        return Float(numStr)
    }
    return Integer(numStr)
}

; Skip whitespace
_skipWhitespace(s, &pos) {
    while (pos <= StrLen(s)) {
        char := SubStr(s, pos, 1)
        if (InStr(" `t`n`r", char)) {
            pos++
        } else {
            break
        }
    }
}

; Dump value
_dumpValue(v) {
    if (v is Map) {
        parts := []
        for key, val in v {
            parts.Push('"' key '":' _dumpValue(val))
        }
        return "{" StrJoin(parts, ",") "}"
    } else if (v is Array) {
        items := []
        for item in v {
            items.Push(_dumpValue(item))
        }
        return "[" StrJoin(items, ",") "]"
    } else if (v is String) {
        return '"' StrReplace(StrReplace(StrReplace(StrReplace(v, '\', '\\'), '`t', '\t'), '`n', '\n'), '"', '\"') '"'
    } else if (v is Integer || v is Float) {
        return String(v)
    } else if (v = true) {
        return "true"
    } else if (v = false) {
        return "false"
    } else {
        return "null"
    }
}

; String join helper
StrJoin(arr, sep) {
    if (arr.Length == 0) {
        return ""
    }

    result := arr[1]
    for i in arr {
        if (A_Index > 1) {
            result .= sep i
        }
    }
    return result
}

; Helper to check if value is string
IsString(v) {
    return (v is String)
}