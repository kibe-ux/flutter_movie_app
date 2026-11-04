function memoryRateStore() {
  const buckets = new Map();
  return {
    buckets,
    async consume(key, now, maximum) {
      const start = Math.floor(now / 60000) * 60000;
      const old = buckets.get(key);
      const hits = old?.start === start ? old.hits : 0;
      if (hits >= maximum) return Math.max(1, Math.ceil((start + 60000 - now) / 1000));
      buckets.set(key, { start, hits: hits + 1 });
      return 0;
    },
    async cleanup() {},
  };
}

module.exports = { memoryRateStore };
