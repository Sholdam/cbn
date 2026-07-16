export class KmsAdapterError extends Error {
  constructor(category) {
    super(category)
    this.name = 'KmsAdapterError'
    this.category = category
  }
}

export function assertKmsAdapter(adapter) {
  const requiredMethods = [
    'wrapKey', 'unwrapKey', 'getKeyReference', 'rewrapDataKey', 'healthCheck'
  ]
  if (!adapter || requiredMethods.some((method) => typeof adapter[method] !== 'function')) {
    throw new KmsAdapterError('kms_adapter_contract_invalid')
  }
  return adapter
}

export function assertKeyReference(reference) {
  if (!reference || typeof reference !== 'object' || Array.isArray(reference)) {
    throw new KmsAdapterError('key_reference_invalid')
  }
  const keys = Object.keys(reference).sort()
  if (keys.join(',') !== 'alias,provider,version' ||
      !/^[a-z][a-z0-9-]{2,40}$/.test(reference.provider) ||
      !/^[A-Za-z0-9][A-Za-z0-9._:/-]{2,254}$/.test(reference.alias) ||
      !/^[A-Za-z0-9][A-Za-z0-9._:-]{0,99}$/.test(reference.version)) {
    throw new KmsAdapterError('key_reference_invalid')
  }
  return reference
}
