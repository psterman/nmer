package main

import (
	"strconv"
	"sync"
	"time"

	"github.com/blugelabs/bluge"
)

const fullTextQueryCacheTTL = 30 * time.Second

type fullTextQueryCacheEntry struct {
	q        bluge.Query
	expireAt time.Time
}

var (
	fullTextQueryCacheMu    sync.Mutex
	fullTextQueryCacheStore = map[string]fullTextQueryCacheEntry{}
)

// bumpFullTextQueryCacheEpoch 在索引批量提交后调用，使查询解析缓存失效。
func bumpFullTextQueryCacheEpoch() {
	fullTextQueryCacheMu.Lock()
	fullTextQueryCacheStore = map[string]fullTextQueryCacheEntry{}
	fullTextQueryCacheMu.Unlock()
}

func lookupFullTextQueryCache(qText string, limit int, build func() bluge.Query) bluge.Query {
	key := qText + "\x00" + strconv.Itoa(limit)
	now := time.Now()

	fullTextQueryCacheMu.Lock()
	defer fullTextQueryCacheMu.Unlock()

	for k, v := range fullTextQueryCacheStore {
		if now.After(v.expireAt) {
			delete(fullTextQueryCacheStore, k)
		}
	}

	if ent, ok := fullTextQueryCacheStore[key]; ok {
		return ent.q
	}
	q := build()
	fullTextQueryCacheStore[key] = fullTextQueryCacheEntry{q: q, expireAt: now.Add(fullTextQueryCacheTTL)}
	return q
}
