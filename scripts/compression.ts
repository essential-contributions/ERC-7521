import { IntentCompression } from './library/intentCompression';
import { StatefulEncoding } from './library/statefulEncoding';
import { ethers } from 'ethers';

// Main script entry
async function main() {
  const encoder = new StatefulEncoding();
  encoder.addOneByteItem('1122334455667788990011223344556677889900112233445566778990011223344556677889900abcdef');
  encoder.addOneByteItem('1122334455667788990011223344556677889900112233445566778990011223344556677889900');
  encoder.addTwoByteItem('1122334455667788990011223344556677889900112233445566778990011223344556677889900abcdef');
  encoder.addTwoByteItem('1122334455667788990011223344556677889900112233445566778990011223344556677889900');
  encoder.addFourByteItem('1122334455667788990011223344556677889900112233445566778990011223344556677889900abcdef');
  encoder.addFourByteItem('1122334455667788990011223344556677889900112233445566778990011223344556677889900');
  ////
  encoder.addOneByteItem('0000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c'); //coin
  encoder.addOneByteItem('0000000000000000000000000000000000000000000000000000000000000002'); //standard
  encoder.addOneByteItem('0000000000000000000000000000000000000000000000000000000000000007'); //standard
  encoder.addOneByteItem('0000000000000000000000000000000000000000000000000000000000000008'); //standard
  encoder.addTwoByteItem('b61d27f6'); //execute function selector
  encoder.addTwoByteItem('a9059cbb'); //erc-20 transfer function selector
  encoder.addFourByteItem('000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266'); //solver
  encoder.addFourByteItem('000000000000000000000000322813fd9a801c5507c9de605d63cea4f2ce6c44'); //sender
  encoder.addFourByteItem('000000000000000000000000a85233c63b9ee964add6f2cffe00fd84eb32338f'); //sender
  encoder.addFourByteItem('0000000000000000000000004a679253410272dd5232b3ff7cf5dbb88f295319'); //sender
  encoder.addFourByteItem('0000000000000000000000007a2088a1bfc9d81c55368ae168c2c02570cb814f'); //sender
  encoder.addFourByteItem('00000000000000000000000009635f643e140090a9a8dcd712ed6285858cebef'); //sender
  encoder.addFourByteItem('000000000000000000000000c5a5c42992decbae36851359345fe25997f5c42d'); //sender
  encoder.addFourByteItem('00000000000000000000000067d269191c92caf3cd7723f116c85e6e9bf55933'); //sender
  encoder.addFourByteItem('000000000000000000000000e6e340d132b5f46d1e472debcd681b2abc16e57e'); //sender
  encoder.addFourByteItem('000000000000000000000000570d116456cff6a7ad3b39db1d1dbdd5c39f227b'); //recipient
  encoder.addFourByteItem('000000000000000000000000734ae4a58c624783eac0004c3bd957694c99b6c1'); //recipient
  encoder.addFourByteItem('000000000000000000000000ca0ac9446a6376cce9d1f3b62f2a7d50932217cc'); //recipient
  encoder.addFourByteItem('0000000000000000000000008f84524e23a57eff9a20157ae3fc1a98aa607028'); //recipient
  encoder.addFourByteItem('000000000000000000000000025d8d9976da50dbc9c5db72e189fbbe7f5ba442'); //recipient
  encoder.addFourByteItem('000000000000000000000000cff016e6dc564a9a73fc06a0f67911faf072df61'); //recipient
  encoder.addFourByteItem('000000000000000000000000672bcc2abed6a9b0c3fbdee1e2c5c727b19d929e'); //recipient
  encoder.addFourByteItem('00000000000000000000000089d37081e4f0e60ccec6584ce146319e35c6b771'); //recipient

  const compression = new IntentCompression(encoder);

  ////////
  const bytes1 =
    '0x4bf114ff0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000006584559b000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000004e00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003c0000000000000000000000000322813fd9a801c5507c9de605d63cea4f2ce6c44000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000020000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c80000000001a658451b30bb8e35fa9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001080000000000000000000000000000000000000000000000000000000000000008000186a0b61d27f60000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000044a9059cbb000000000000000000000000570d116456cff6a7ad3b39db1d1dbdd5c39f227b0000000000000000000000000000000000000000000000008ac7230489e80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041ef3cfcc6606d9412eda24b76b4d8a53bd7c42fbbabcd3b9e5762b9cad6661fb2020b58b9254aac1a53d704cdcc51da0e137227531602300ecb62527d45cf79141c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000';
  const bytes4 =
    '0x4bf114ff0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000006584559b00000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000fc0000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000042000000000000000000000000000000000000000000000000000000000000007a00000000000000000000000000000000000000000000000000000000000000b200000000000000000000000000000000000000000000000000000000000000ea0000000000000000000000000322813fd9a801c5507c9de605d63cea4f2ce6c44000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000020000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c80000000001a658451b30bb8e35fa9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001080000000000000000000000000000000000000000000000000000000000000008000186a0b61d27f60000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000044a9059cbb000000000000000000000000570d116456cff6a7ad3b39db1d1dbdd5c39f227b0000000000000000000000000000000000000000000000008ac7230489e80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041ef3cfcc6606d9412eda24b76b4d8a53bd7c42fbbabcd3b9e5762b9cad6661fb2020b58b9254aac1a53d704cdcc51da0e137227531602300ecb62527d45cf79141c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000a85233c63b9ee964add6f2cffe00fd84eb32338f000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000020000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c80000000001a658451b30bb8e35fa9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001080000000000000000000000000000000000000000000000000000000000000008000186a0b61d27f60000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000044a9059cbb000000000000000000000000734ae4a58c624783eac0004c3bd957694c99b6c10000000000000000000000000000000000000000000000008ac7230489e8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004105c3b6846be54653a7d79f1b02b27135f9586bc4d36c606c1afb0d534a8668b556fcc71fbff8fc1b9e693f5f836e9289669a60e298e24d26e294ad6c89b1b03e1c000000000000000000000000000000000000000000000000000000000000000000000000000000000000004a679253410272dd5232b3ff7cf5dbb88f295319000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000020000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c80000000001a658451b30bb8e35fa9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001080000000000000000000000000000000000000000000000000000000000000008000186a0b61d27f60000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000044a9059cbb000000000000000000000000ca0ac9446a6376cce9d1f3b62f2a7d50932217cc0000000000000000000000000000000000000000000000008ac7230489e80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041c8fae215eae1f4f36abc314919a75546190149adc870e46b1fbb42bcee7c5b5d3a386743a523a9957474633ab51f86e3d05c6f132f04cf333e8775492a39258f1b000000000000000000000000000000000000000000000000000000000000000000000000000000000000007a2088a1bfc9d81c55368ae168c2c02570cb814f000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000020000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c80000000001a658451b30bb8e35fa9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001080000000000000000000000000000000000000000000000000000000000000008000186a0b61d27f60000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000044a9059cbb0000000000000000000000008f84524e23a57eff9a20157ae3fc1a98aa6070280000000000000000000000000000000000000000000000008ac7230489e80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041d9e1e9e0921ba8c02959f4b23b7479698e88dc08cd5fae416f685385102d81c520c0763d9e60b80f6ed852d420ff7b7d89ecc60d92ad38e027ed2e94c05764c21b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000003';
  const bytes8 =
    '0x4bf114ff0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000006584559b00000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000001e400000000000000000000000000000000000000000000000000000000000000009000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000004a000000000000000000000000000000000000000000000000000000000000008200000000000000000000000000000000000000000000000000000000000000ba00000000000000000000000000000000000000000000000000000000000000f2000000000000000000000000000000000000000000000000000000000000012a0000000000000000000000000000000000000000000000000000000000000162000000000000000000000000000000000000000000000000000000000000019a00000000000000000000000000000000000000000000000000000000000001d20000000000000000000000000322813fd9a801c5507c9de605d63cea4f2ce6c44000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000020000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c80000000001a658451b30bb8e35fa9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001080000000000000000000000000000000000000000000000000000000000000008000186a0b61d27f60000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000044a9059cbb000000000000000000000000570d116456cff6a7ad3b39db1d1dbdd5c39f227b0000000000000000000000000000000000000000000000008ac7230489e80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041ef3cfcc6606d9412eda24b76b4d8a53bd7c42fbbabcd3b9e5762b9cad6661fb2020b58b9254aac1a53d704cdcc51da0e137227531602300ecb62527d45cf79141c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000a85233c63b9ee964add6f2cffe00fd84eb32338f000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000020000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c80000000001a658451b30bb8e35fa9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001080000000000000000000000000000000000000000000000000000000000000008000186a0b61d27f60000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000044a9059cbb000000000000000000000000734ae4a58c624783eac0004c3bd957694c99b6c10000000000000000000000000000000000000000000000008ac7230489e8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004105c3b6846be54653a7d79f1b02b27135f9586bc4d36c606c1afb0d534a8668b556fcc71fbff8fc1b9e693f5f836e9289669a60e298e24d26e294ad6c89b1b03e1c000000000000000000000000000000000000000000000000000000000000000000000000000000000000004a679253410272dd5232b3ff7cf5dbb88f295319000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000020000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c80000000001a658451b30bb8e35fa9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001080000000000000000000000000000000000000000000000000000000000000008000186a0b61d27f60000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000044a9059cbb000000000000000000000000ca0ac9446a6376cce9d1f3b62f2a7d50932217cc0000000000000000000000000000000000000000000000008ac7230489e80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041c8fae215eae1f4f36abc314919a75546190149adc870e46b1fbb42bcee7c5b5d3a386743a523a9957474633ab51f86e3d05c6f132f04cf333e8775492a39258f1b000000000000000000000000000000000000000000000000000000000000000000000000000000000000007a2088a1bfc9d81c55368ae168c2c02570cb814f000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000020000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c80000000001a658451b30bb8e35fa9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001080000000000000000000000000000000000000000000000000000000000000008000186a0b61d27f60000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000044a9059cbb0000000000000000000000008f84524e23a57eff9a20157ae3fc1a98aa6070280000000000000000000000000000000000000000000000008ac7230489e80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041d9e1e9e0921ba8c02959f4b23b7479698e88dc08cd5fae416f685385102d81c520c0763d9e60b80f6ed852d420ff7b7d89ecc60d92ad38e027ed2e94c05764c21b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000009635f643e140090a9a8dcd712ed6285858cebef000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000020000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c80000000001a658451b30bb8e35fa9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001080000000000000000000000000000000000000000000000000000000000000008000186a0b61d27f60000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000044a9059cbb000000000000000000000000025d8d9976da50dbc9c5db72e189fbbe7f5ba4420000000000000000000000000000000000000000000000008ac7230489e80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041f26e33eb5c667ac9a3efe6c49843ca8d5008e2841f85a6c114e4f203678aa477364d2b3afc22bb6b59dc745d63faf925275fdd18b6b398f0d18d9a48d979b0191b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000c5a5c42992decbae36851359345fe25997f5c42d000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000020000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c80000000001a658451b30bb8e35fa9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001080000000000000000000000000000000000000000000000000000000000000008000186a0b61d27f60000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000044a9059cbb000000000000000000000000cff016e6dc564a9a73fc06a0f67911faf072df610000000000000000000000000000000000000000000000008ac7230489e80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041f91e084c9daa81030ab9e478bc202c213f083880d58a56bb88d9993138cdee5641391b2e4ed2f83c45a7eac5b1564825f178df748e6b0a252d7414853205db591c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000067d269191c92caf3cd7723f116c85e6e9bf55933000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000020000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c80000000001a658451b30bb8e35fa9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001080000000000000000000000000000000000000000000000000000000000000008000186a0b61d27f60000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000044a9059cbb000000000000000000000000672bcc2abed6a9b0c3fbdee1e2c5c727b19d929e0000000000000000000000000000000000000000000000008ac7230489e80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041431726ee8505407daddd9e5c8f56fbc2ec5fea38a478623b54ffa0b91e21c46940d1bddec420da6794f1497ca55afb16d48d67f242266b2a9b50dfcb63b9abaa1b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000e6e340d132b5f46d1e472debcd681b2abc16e57e000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000020000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c80000000001a658451b30bb8e35fa9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001080000000000000000000000000000000000000000000000000000000000000008000186a0b61d27f60000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000044a9059cbb00000000000000000000000089d37081e4f0e60ccec6584ce146319e35c6b7710000000000000000000000000000000000000000000000008ac7230489e800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000412166a538b6befffa4500371ec9725b2f210faa2dcceaabc5f0001bc5d6618451244aee992c340e8ae32f7d5c692feb0ac8ce2b20b3f3b721ebe8bc481a6ef5501b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb922660000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000007';

  console.log('start');
  console.log(bytes8);
  console.log();

  const encoded = encoder.encode(bytes8);
  console.log('encoded (stateful abi encoder)');
  console.log(encoded);
  console.log();

  const compressed = compression.compressHandleIntentsRaw(bytes8);
  console.log('compressed (solution templating)');
  console.log(compressed);
  console.log();

  const decompressed = compression.decompressHandleIntentsRaw(compressed);

  if (decompressed == bytes8) console.log('MATCH!');
  else {
    console.log('decompressed');
    console.log(decompressed);
    console.log();
    console.log('ERROR: DOES NOT MATCH');
  }
  console.log();
  console.log();

  const baseCost = gasCost(
    '0x02f8b3827a693a843b9aca00843ba6784c8401c9c380943aa5ebb10dc797cac828524e59a333d0a371443c80b844a9059cbb000000000000000000000000157fa2fe60d396b026988cad337215681342bc1f0000000000000000000000000000000000000000000000008ac7230489e80000c080a078e5c814993ba9c1fea513b8f7165352d9cffcf8cecd32f89128b08756f6ce88a02c685bcc0ecb9150b5c53ee6e399f673bb976fd071f33c129ffab257f64fb6a7',
  );
  console.log('base cost: ' + baseCost);
  console.log();
  console.log('-- batch of 1 --');
  const rawCost1 = Math.ceil(gasCost(bytes1) / 1);
  const encodedCost1 = Math.ceil(gasCost(encoder.encode(bytes1)) / 1);
  const compressedCost1 = Math.ceil(gasCost(compression.compressHandleIntentsRaw(bytes1)) / 1);
  console.log('raw cost: ' + rawCost1 + ' ' + percent(baseCost, rawCost1));
  console.log('encoded cost: ' + encodedCost1 + ' ' + percent(baseCost, encodedCost1));
  console.log('compressed cost: ' + compressedCost1 + ' ' + percent(baseCost, compressedCost1));
  console.log();
  console.log('-- batch of 4 --');
  const rawCost4 = Math.ceil(gasCost(bytes4) / 4);
  const encodedCost4 = Math.ceil(gasCost(encoder.encode(bytes4)) / 4);
  const compressedCost4 = Math.ceil(gasCost(compression.compressHandleIntentsRaw(bytes4)) / 4);
  console.log('raw cost: ' + rawCost4 + ' ' + percent(baseCost, rawCost4));
  console.log('encoded cost: ' + encodedCost4 + ' ' + percent(baseCost, encodedCost4));
  console.log('compressed cost: ' + compressedCost4 + ' ' + percent(baseCost, compressedCost4));
  console.log();
  console.log('-- batch of 8 --');
  const rawCost8 = Math.ceil(gasCost(bytes8) / 8);
  const encodedCost8 = Math.ceil(gasCost(encoded) / 8);
  const compressedCost8 = Math.ceil(gasCost(compressed) / 8);
  console.log('raw cost: ' + rawCost8 + ' ' + percent(baseCost, rawCost8));
  console.log('encoded cost: ' + encodedCost8 + ' ' + percent(baseCost, encodedCost8));
  console.log('compressed cost: ' + compressedCost8 + ' ' + percent(baseCost, compressedCost8));
}

// Start script
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

function gasCost(bytes: string): number {
  let gas = 0;
  for (let i = 2; i < bytes.length; i++) {
    if (bytes.substring(i, i + 2) == '00') gas += 4;
    else gas += 16;
  }
  return gas;
}
function percent(before: number, now: number): string {
  let v = 0;
  let n = false;
  let p = '';
  if (before > now) {
    n = true;
    v = (before - now) / before;
    p = `-${Math.round(v * 1000) / 10}%`;
  } else {
    n = false;
    v = (now - before) / before;
    p = `+${Math.round(v * 1000) / 10}%`;
  }
  if (p.length > 7 && p.indexOf('.') > -1) p = `${p.substring(0, p.indexOf('.'))}%`;

  if (n) return '\x1b[32m' + p + '\x1b[0m';
  if (v < 1) return '\x1b[33m' + p + '\x1b[0m';
  return '\x1b[31m' + p + '\x1b[0m';
}
