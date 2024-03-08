import function_signatures from './data/function_signatures.json';

const SIGNATURE_MAP = new Map<string, ParamType[]>();

// Initialization function
export function initCalldataUtils() {
  if (SIGNATURE_MAP.size == 0) {
    const signatures = function_signatures as string[];
    for (let i = 0; i < signatures.length; i++) {
      try {
        const split = splitSignature(signatures[i]);
        SIGNATURE_MAP.set(split.name, paramTypes(split.params));
      } catch (e) {
        console.log(e);
      }
    }
  }
}

// Breaks down the given calldata into identified chunks
export function breakdownCalldata(calldata: string): Chunk[] {
  initCalldataUtils();
  if (calldata.substring(0, 2) == '0x') calldata = calldata.slice(2);

  const chunks = bytesToChunks(calldata);
  if (!validateChunks(calldata, chunks)) return [{ type: 'bytes', data: calldata, length: calldata.length / 2 }];
  return chunks;
}

// Breaks down the given calldata into identified chunks
export function splitRawCalldata(calldata: string): Uint8Array[] {
  initCalldataUtils();
  if (calldata.substring(0, 2) == '0x') calldata = calldata.slice(2);

  const chunks = bytesToChunks(calldata);
  if (!validateChunks(calldata, chunks)) return [toBeArray(calldata)];

  const parts: Uint8Array[] = [];
  for (let i = 0; i < chunks.length; i++) parts.push(toBeArray(chunks[i].data));
  return parts;
}

// Chunking utils
function bytesToChunks(data: string, length?: number): Chunk[] {
  if (length === undefined) length = data.length / 2;
  const fnsel = data.substring(0, 8);
  const fndata = data.substring(8);
  const expectedIndexEnd = (length - 4) * 2;
  const padding = length == data.length / 2 ? undefined : ''.padEnd(data.length - length * 2, '0');

  const params = SIGNATURE_MAP.get(fnsel);
  if (params !== undefined) {
    try {
      const ch = chunk(fndata, 0, params);
      if (ch.index != expectedIndexEnd) throw new Error('Incomplete chunking');

      const chunks: Chunk[] = [{ type: 'fnsel', data: fnsel }, ...ch.chunks];
      if (padding !== undefined) chunks.push({ type: 'padding', data: padding });
      return chunks;
    } catch (e) {}
  }
  return [{ type: 'bytes', data, length }];
}
function chunk(
  data: string,
  index: number,
  params: ParamType[],
  alreadyPointed: boolean = false,
): { chunks: Chunk[]; index: number } {
  const startIndex = index;
  const chunks: Chunk[] = [];

  //first pass through all params
  const pointed: number[] = [];
  for (let i = 0; i < params.length; i++) {
    const param = params[i];
    if (fixed(param) || alreadyPointed) {
      let ch: { chunks: Chunk[]; index: number } = { chunks: [], index };
      if (param.type == 'tuple') ch = chunk(data, index, param.params);
      else if (param.type == 'array') ch = chunkArray(data, index, param.param);
      else if (param.type == 'string') ch = chunkString(data, index);
      else if (param.type == 'bytes') ch = chunkBytes(data, index);
      else ch = chunkFixed(data, index, param);
      chunks.push(...ch.chunks);
      index = ch.index;
    } else {
      const err = 'Invalid formatting';
      chunks.push({ type: 'pointer', data: safeSubstring(data, index, index + 64, err) });
      pointed[i] = parseInt(safeSubstring(data, index, index + 64, err), 16) * 2;
      index += 64;
    }
  }

  //follow up on pointed data
  for (let i = 0; i < pointed.length; i++) {
    if (pointed[i]) {
      const param = params[i];
      let ch: { chunks: Chunk[]; index: number } = { chunks: [], index };
      if (param.type == 'tuple') ch = chunk(data, startIndex + pointed[i], param.params);
      else if (param.type == 'array') ch = chunkArray(data, startIndex + pointed[i], param.param);
      else if (param.type == 'string') ch = chunkString(data, startIndex + pointed[i]);
      else if (param.type == 'bytes') ch = chunkBytes(data, startIndex + pointed[i]);
      chunks.push(...ch.chunks);
      index = ch.index;
    }
  }

  return { chunks, index };
}
function chunkArray(
  data: string,
  index: number,
  param: ParamType,
  length?: number,
): { chunks: Chunk[]; index: number } {
  //TODO: use length
  const err = 'Invalid array formatting';
  const chunks: Chunk[] = [];
  const len = safeSubstring(data, index, index + 64, err);
  length = parseInt(len, 16);
  chunks.push({ type: 'length', data: len });
  if (fixed(param)) {
    index += 64;
    for (let j = 0; j < length; j++) {
      if (index >= data.length) throw new Error(err);
      const ch = chunk(data, index, [param], true);
      chunks.push(...ch.chunks);
      index = ch.index;
    }
  } else {
    const start = index + 64;
    const ptrs: number[] = [];
    for (let j = 0; j < length; j++) {
      const ptr = safeSubstring(data, start + j * 64, start + (j + 1) * 64, err);
      chunks.push({ type: 'pointer', data: ptr });
      ptrs.push(parseInt(ptr, 16) * 2);
    }
    for (let j = 0; j < length; j++) {
      if (start + ptrs[j] >= data.length) throw new Error(err);
      const ch = chunk(data, start + ptrs[j], [param], true);
      chunks.push(...ch.chunks);
      index = ch.index;
    }
  }
  return { chunks, index };
}
function chunkString(data: string, index: number): { chunks: Chunk[]; index: number } {
  const err = 'Invalid string formatting';
  const len = safeSubstring(data, index, index + 64, err);
  const chunks: Chunk[] = [{ type: 'length', data: len }];

  const length = parseInt(len, 16);
  const paddedLength = Math.ceil(length / 32) * 32;
  const bytesData = safeSubstring(data, index + 64, index + 64 + paddedLength * 2, err);
  chunks.push({ type: 'string', data: bytesData, length });
  return { chunks, index: index + 64 + paddedLength * 2 };
}
function chunkBytes(data: string, index: number): { chunks: Chunk[]; index: number } {
  const err = 'Invalid bytes formatting';
  const len = safeSubstring(data, index, index + 64, err);
  const chunks: Chunk[] = [{ type: 'length', data: len }];

  const length = parseInt(len, 16);
  const paddedLength = Math.ceil(length / 32) * 32;
  const bytesData = safeSubstring(data, index + 64, index + 64 + paddedLength * 2, err);

  //try to chunk the bytes
  chunks.push(...bytesToChunks(bytesData, length));
  return { chunks, index: index + 64 + paddedLength * 2 };
}
function chunkFixed(data: string, index: number, param: ParamType): { chunks: Chunk[]; index: number } {
  const err = 'Invalid formatting';
  const d = safeSubstring(data, index, index + 64, err);
  if (param.type == 'address') {
    return { chunks: [{ type: 'address', data: d }], index: index + 64 };
  } else if (param.type == 'bool') {
    return { chunks: [{ type: 'bool', data: d }], index: index + 64 };
  } else if (param.type == 'int' || param.type == 'uint') {
    return { chunks: [{ type: 'number', data: d }], index: index + 64 };
  } else if (param.type == 'bytesn') {
    return { chunks: [{ type: 'bytes', data: d, length: param.numBytes }], index: index + 64 };
  }
  throw new Error(err);
}
function safeSubstring(str: string, start: number, end?: number, err?: string): string {
  if (end === undefined) end = str.length;
  if (start >= str.length) throw new Error(err);
  if (end > str.length) throw new Error(err);
  if (end < start) throw new Error(err);
  return str.substring(start, end);
}
function validateChunks(data: string, chunks: Chunk[]): boolean {
  let compiled = '';
  for (let i = 0; i < chunks.length; i++) compiled += chunks[i].data;
  return compiled == data;
}
export type ChunkPointer = {
  type: 'pointer';
  data: string;
};
export type ChunkLength = {
  type: 'length';
  data: string;
};
export type ChunkAddress = {
  type: 'address';
  data: string;
};
export type ChunkBool = {
  type: 'bool';
  data: string;
};
export type ChunkString = {
  type: 'string';
  data: string;
  length: number;
};
export type ChunkBytes = {
  type: 'bytes';
  data: string;
  length: number;
};
export type ChunkNumber = {
  type: 'number';
  data: string;
};
export type ChunkPadding = {
  type: 'padding';
  data: string;
};
export type ChunkFnSel = {
  type: 'fnsel';
  data: string;
};
export type Chunk =
  | ChunkPointer
  | ChunkLength
  | ChunkAddress
  | ChunkBool
  | ChunkString
  | ChunkBytes
  | ChunkNumber
  | ChunkPadding
  | ChunkFnSel;

// Param types
function paramTypes(functionParams: string): ParamType[] {
  const params: ParamType[] = [];
  for (let i = 0; i < functionParams.length; i++) {
    if (functionParams[i] == '(') {
      //recursive call on the tuple
      let open = 1;
      let end = -1;
      for (let j = i + 1; j < functionParams.length; j++) {
        if (functionParams[j] == '(') open++;
        if (functionParams[j] == ')') {
          open--;
          if (open == 0) {
            end = j + 1;
            break;
          }
        }
      }
      if (end == -1) throw new Error('Invalid tuple formatting');
      const param: ParamTypeTuple = { type: 'tuple', params: paramTypes(functionParams.slice(i + 1, end - 1)) };
      const check = checkArray(functionParams, end, param);
      params.push(check.param);
      i = check.index - 1;
    } else {
      //non tuple parameter
      let end = functionParams.length;
      for (let j = i; j < functionParams.length; j++) {
        if (functionParams[j] == ',' || functionParams[j] == '[') {
          end = j;
          break;
        }
      }
      const param = paramType(functionParams.slice(i, end));
      const check = checkArray(functionParams, end, param);
      params.push(check.param);
      i = check.index - 1;
    }
  }
  return params;
}
function checkArray(paramStr: string, at: number, param: ParamType): { param: ParamType; index: number } {
  if (at >= paramStr.length) return { param, index: at };
  if (paramStr[at] == ',') return { param, index: at + 1 };
  if (paramStr[at] == '[') {
    const end = paramStr.indexOf(']', at);
    if (end < 0) throw new Error('Invalid array start');

    const lengthStr = paramStr.slice(at + 1, end);
    if (lengthStr == '') return checkArray(paramStr, end + 1, { type: 'array', param });

    const length = parseInt(lengthStr);
    if (isNaN(length) || length === 0) throw new Error('Invalid array length');
    return checkArray(paramStr, end + 1, { type: 'array', param, length });
  }
  throw new Error('Param parse error');
}
function paramType(param: string): ParamType {
  if (param == 'a') return { type: 'address' };
  if (param == 'o') return { type: 'bool' };
  if (param == 's') return { type: 'string' };
  if (param == 'b') return { type: 'bytes' };
  if (param.indexOf('i') == 0) return { type: 'int', numBits: parseInt(param.substring(1)) };
  if (param.indexOf('u') == 0) return { type: 'uint', numBits: parseInt(param.substring(1)) };
  if (param.indexOf('b') == 0) return { type: 'bytesn', numBytes: parseInt(param.substring(1)) };
  throw new Error('Unknown param type: ' + param);
}
function fixed(params: ParamType | ParamType[]): boolean {
  if (!Array.isArray(params)) params = [params];
  for (const param of params) {
    if (param.type == 'tuple') {
      return fixed(param.params);
    }
    if (param.type == 'array') {
      if (param.length === undefined) return false;
      return fixed(param.param);
    }
    if (param.type == 'string' || param.type == 'bytes') return false;
  }
  return true;
}
type ParamTypeTuple = {
  type: 'tuple';
  params: ParamType[];
};
type ParamTypeArray = {
  type: 'array';
  param: ParamType;
  length?: number;
};
type ParamTypeAddress = {
  type: 'address';
};
type ParamTypeBool = {
  type: 'bool';
};
type ParamTypeString = {
  type: 'string';
};
type ParamTypeBytes = {
  type: 'bytes';
};
type ParamTypeInt = {
  type: 'int';
  numBits: number;
};
type ParamTypeUint = {
  type: 'uint';
  numBits: number;
};
type ParamTypeFixedBytes = {
  type: 'bytesn';
  numBytes: number;
};
type ParamType =
  | ParamTypeTuple
  | ParamTypeArray
  | ParamTypeAddress
  | ParamTypeBool
  | ParamTypeString
  | ParamTypeBytes
  | ParamTypeInt
  | ParamTypeUint
  | ParamTypeFixedBytes;

// Utils
function splitSignature(signature: string): { name: string; params: string } {
  const firstParen = signature.indexOf('(');
  if (firstParen > -1 && signature[signature.length - 1] == ')') {
    return {
      name: signature.substring(0, firstParen),
      params: signature.substring(firstParen + 1, signature.length - 1),
    };
  }
  throw new Error('Invalid signature text');
}
export function toBeArray(hex: string): Uint8Array {
  if (hex.indexOf('0x') == 0) hex = hex.substring(2);
  const result = new Uint8Array(hex.length / 2);
  for (let i = 0; i < result.length; i++) {
    const offset = i * 2;
    result[i] = parseInt(hex.substring(offset, offset + 2), 16);
  }
  return result;
}
