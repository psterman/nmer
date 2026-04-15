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
    maxPos := StrLen(s)
    guard := 0

    while (pos <= maxPos) {
        guard++
        if (guard > maxPos + 8)
            throw Error("JSON object parse overflow")

        before := pos
        _skipWhitespace(s, &pos)

        if (SubStr(s, pos, 1) == "}") {
            pos++
            break
        }

        ; Parse key
        if (SubStr(s, pos, 1) != '"')
            throw Error("JSON object key must be quoted")
        key := _parseValue(s, &pos)
        if (!IsString(key)) {
            key := String(key)
        }

        ; Skip colon
        _skipWhitespace(s, &pos)
        if (SubStr(s, pos, 1) != ":")
            throw Error("JSON object missing colon")
        pos++

        ; Parse value
        value := _parseValue(s, &pos)
        obj[key] := value

        ; Skip comma
        _skipWhitespace(s, &pos)
        ch := SubStr(s, pos, 1)
        if (ch == ",") {
            pos++
        } else if (ch == "}") {
            pos++
            break
        } else {
            throw Error("JSON object missing comma")
        }

        if (pos <= before)
            throw Error("JSON object parser stalled")
    }

    return obj
}

; Parse array
_parseArray(s, &pos) {
    arr := []
    maxPos := StrLen(s)
    guard := 0

    while (pos <= maxPos) {
        guard++
        if (guard > maxPos + 8)
            throw Error("JSON array parse overflow")

        before := pos
        _skipWhitespace(s, &pos)

        if (SubStr(s, pos, 1) == "]") {
            pos++
            break
        }

        value := _parseValue(s, &pos)
        arr.Push(value)

        _skipWhitespace(s, &pos)
        ch := SubStr(s, pos, 1)
        if (ch == ",") {
            pos++
        } else if (ch == "]") {
            pos++
            break
        } else {
            throw Error("JSON array missing comma")
        }

        if (pos <= before)
            throw Error("JSON array parser stalled")
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
    t := Type(v)
    if (t == "Map") {
        parts := []
        for key, val in v {
            parts.Push('"' . key . '":' . _dumpValue(val))
        }
        return "{" . StrJoin(parts, ",") . "}"
    } else if (t == "Array") {
        items := []
        for item in v {
            items.Push(_dumpValue(item))
        }
        return "[" . StrJoin(items, ",") . "]"
    } else if (t == "String") {
        return '"' . StrReplace(StrReplace(StrReplace(StrReplace(v, '\', '\\'), '`t', '\t'), '`n', '\n'), '"', '\"') . '"'
    } else if (t == "Integer" || t == "Float") {
        ; AHK v2 中 true/false 也是 Integer，这里直接输出数字以保证数据严谨
        return String(v)
    } else if (IsObject(v)) {
        parts := []
        for prop in v.OwnProps() {
            parts.Push('"' . prop . '":' . _dumpValue(v.%prop%))
        }
        return "{" . StrJoin(parts, ",") . "}"
    } else {
        return "null"
    }
}

; String join helper
StrJoin(arr, sep) {
    if (Type(arr) != "Array" || arr.Length == 0) {
        return ""
    }

    result := arr[1]
    for idx, val in arr {
        if (idx > 1) {
            result .= sep . val
        }
    }
    return result
}

; Helper to check if value is string
IsString(v) {
    return (v is String)
}
