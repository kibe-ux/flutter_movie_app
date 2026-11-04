// Final fail-closed gate immediately before publishing any production rules.
function requireReadyIndexes(indexes, fields, expectedIndexes, expectedFields) {
  if (!Array.isArray(indexes) || indexes.length !== expectedIndexes ||
      !Array.isArray(fields) || fields.length !== expectedFields) {
    throw new Error('Required index verification is incomplete; rules will not be published.');
  }
  for (const index of indexes) {
    if (index?.state !== 'READY') throw new Error('A composite index is not READY; rules will not be published.');
  }
  for (const field of fields) {
    if (!Array.isArray(field?.indexConfig?.indexes) || field.indexConfig.indexes.length === 0 ||
        field.indexConfig.indexes.some((index) => index.state !== 'READY')) {
      throw new Error('A field index is not READY; rules will not be published.');
    }
  }
}
module.exports = { requireReadyIndexes };
