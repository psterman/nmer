; Jxon - 极简化JSON处理 (无类版本)
#Requires AutoHotkey v2.0

; 极简化的JSON解析器
Jxon_Load(&src) {
    src := Trim(src)
    if !src || SubStr(src, 1, 1) != "{"
        return {}
        
    result := Map()
    content := SubStr(src, 2, -1)
    
    ; 简单的键值对提取
    parts := StrSplit(content, ",")
    for part in parts {
        if (InStr(part, ":")) {
            keyValuePair := StrSplit(part, ":")
            if (keyValuePair.Length >= 2) {
                key := Trim(keyValuePair[1], ' "{[]}')
                value := Trim(keyValuePair[2], ' "{[]}')
                if (key && value) {
                    ; 移除引号
                    key := StrReplace(key, '"', "")
                    value := StrReplace(value, '"', "")
                    result[key] := value
                }
            }
        }
    }
    
    return result
}

Jxon_Dump(obj) {
    if (obj is Map) {
        result := "{"
        first := true
        for key, value in obj {
            if (!first) {
                result .= ","
            }
            result .= '"' key '":"' value '"'
            first := false
        }
        result .= "}"
        return result
    } else if (obj is Array) {
        result := "["
        first := true
        for item in obj {
            if (!first) {
                result .= ","
            }
            result .= '"' item '"'
            first := false
        }
        result .= "]"
        return result
    } else {
        return String(obj)
    }
}

; 简化版JSON类 - 用于复杂对象
class SimpleJSON {
    static parse(jsonStr) {
        jsonStr := Trim(jsonStr)
        if (SubStr(jsonStr, 1, 1) == "{") {
            result := Map()
            content := SubStr(jsonStr, 2, -1)
            Loop Parse content, ',"' {
                if (InStr(A_LoopField, ":")) {
                    parts := StrSplit(A_LoopField, ":", , 2)
                    if (parts.Length == 2) {
                        key := Trim(parts[1], '" ')
                        value := Trim(parts[2], '" ')
                        result[key] := value
                    }
                }
            }
            return result
        }
        return jsonStr
    }

    static stringify(obj) {
        if (obj is Map) {
            result := "{"
            first := true
            for key, value in obj {
                if (!first) result .= ","
                result .= '"' key '":"' String(value) '"'
                first := false
            }
            result .= "}"
            return result
        }
        return String(obj)
    }
}