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
; 注意：AHK v2 的转义字符是反引号(`)，不是反斜杠(\)。
; 所以源码里要表示 "单个反斜杠" 就是 "\"，要表示 "双引号" 就是 '"'。
; 旧实现用 "\\" 比较单字符 char，永远不会成立，导致 JSON 中的所有
; \" \\ \n 等转义都被错误处理，进而把 \" 后的 " 当成字符串结束符，
; 整个 JSON 解析失败回退成空 Map()，是单字符搜索"无结果"的根因。
_parseString(s, &pos) {
    pos++ ; skip opening quote
    result := ""
    sLen := StrLen(s)

    while (pos <= sLen) {
        char := SubStr(s, pos, 1)
        pos++

        if (char == '"') {
            break
        } else if (char == "\") {
            if (pos <= sLen) {
                next := SubStr(s, pos, 1)
                pos++
                switch next {
                    case '"': result .= '"'
                    case "\": result .= "\"
                    case "/": result .= "/"
                    case "n": result .= "`n"
                    case "r": result .= "`r"
                    case "t": result .= "`t"
                    case "b": result .= "`b"
                    case "f": result .= "`f"
                    case "u":
                        ; \uXXXX —— 解析 4 位十六进制 Unicode 码点
                        if (pos + 3 <= sLen) {
                            hex := SubStr(s, pos, 4)
                            pos += 4
                            try {
                                code := Integer("0x" . hex)
                                ; 处理 BMP 之外的代理对（高代理 0xD800-0xDBFF）
                                if (code >= 0xD800 && code <= 0xDBFF
                                    && pos + 5 <= sLen
                                    && SubStr(s, pos, 2) == "\u") {
                                    hex2 := SubStr(s, pos + 2, 4)
                                    try {
                                        low := Integer("0x" . hex2)
                                        if (low >= 0xDC00 && low <= 0xDFFF) {
                                            pos += 6
                                            code := 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
                                        }
                                    }
                                }
                                result .= Chr(code)
                            } catch {
                                result .= next
                            }
                        } else {
                            result .= next
                        }
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
    bom := Chr(0xFEFF)
    while (pos <= StrLen(s)) {
        char := SubStr(s, pos, 1)
        if (char = bom || InStr(" `t`n`r", char)) {
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
        ; 必须先转义反斜杠本身，再转义其它特殊字符；同样注意 AHK v2 中
        ; "\\" 是两个字符，所以这里用 "\" 表示单反斜杠、"\\" 表示双反斜杠。
        esc := StrReplace(v, "\", "\\")
        esc := StrReplace(esc, '"', '\"')
        esc := StrReplace(esc, "`b", "\b")
        esc := StrReplace(esc, "`f", "\f")
        esc := StrReplace(esc, "`n", "\n")
        esc := StrReplace(esc, "`r", "\r")
        esc := StrReplace(esc, "`t", "\t")
        return '"' . esc . '"'
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
