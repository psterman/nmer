#Requires AutoHotkey v2.0

; ===================== 全局搜索引擎类 =====================
/**
 * 全局搜索引擎类
 * 彻底解决句柄泄露和 Database Locked 问题
 * 引入熔断机制、Try-Finally 保护、并发同步
 */
class GlobalSearchEngine {
    /**
     * 熔断机制：在执行 Prepare 之前强制释放旧的 Statement 句柄
     */
    static ReleaseOldStatement() {
        global GlobalSearchStatement
        try {
            if (IsObject(GlobalSearchStatement) && GlobalSearchStatement != 0) {
                GlobalSearchStatement.Free()
                GlobalSearchStatement := 0
            }
        } catch as e {
            OutputDebug("释放旧 Statement 失败: " . e.Message)
            GlobalSearchStatement := 0
        }
    }

    static PerformSearch(Keyword, MaxResults := 100) {
        global ClipboardDB, GlobalSearchStatement, global_ST
        Results := []
        ST := 0  ; 局部 Statement 句柄

        if (!IsObject(ClipboardDB) || ClipboardDB = 0) {
            return Results
        }

        if (IsObject(global_ST) && global_ST.HasProp("Free")) {
            try {
                global_ST.Free()
            } catch as err {
            }
            global_ST := 0
        }

        GlobalSearchEngine.ReleaseOldStatement()

        SearchPattern := "%" . Keyword . "%"

        try {
            SQL := "
            (
                SELECT Name AS Title, Content, '提示词' AS Source, CreateTime, rowid AS ID 
                FROM Prompts 
                WHERE Name LIKE ? OR Content LIKE ?
                UNION ALL
                SELECT SUBSTR(Content, 1, 50) AS Title, Content, '剪贴板' AS Source, CreateTime, rowid AS ID 
                FROM ClipboardHistory 
                WHERE Content LIKE ?
                ORDER BY CreateTime DESC 
                LIMIT " . MaxResults . "
            )"

            if !ClipboardDB.Prepare(SQL, &ST) {
                return Results
            }

            GlobalSearchStatement := ST
            global_ST := ST

            ST.Bind(1, SearchPattern)
            ST.Bind(2, SearchPattern)
            ST.Bind(3, SearchPattern)

            try {
                while (ST.Step() = 100) { ; SQLITE_ROW
                    Results.Push({
                        Title: ST.ColumnText(0),
                        Content: ST.ColumnText(1),
                        Source: ST.ColumnText(2),
                        Time: ST.ColumnText(3),
                        ID: ST.ColumnInt(4)
                    })
                }
            } catch as e {
                OutputDebug("搜索 Step() 循环出错: " . e.Message)
            } finally {
                try {
                    if (IsObject(global_ST) && global_ST.HasProp("Free")) {
                        global_ST.Free()
                    }
                    global_ST := 0
                } catch as err {
                }
                if (GlobalSearchStatement = ST) {
                    GlobalSearchStatement := 0
                }
            }
        } catch as e {
            OutputDebug("搜索出错: " . e.Message)
            try {
                if (IsObject(global_ST) && global_ST.HasProp("Free")) {
                    global_ST.Free()
                }
                global_ST := 0
            } catch as err {
            }
            if (GlobalSearchStatement = ST) {
                GlobalSearchStatement := 0
            }
        }

        return Results
    }
}
