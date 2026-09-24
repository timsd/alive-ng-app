import fs from 'node:fs';
import zlib from 'node:zlib';

function readZip(zipPath) {
  const buf = fs.readFileSync(zipPath);
  let pos = 0;
  const entries = [];
  while (pos < buf.length - 4) {
    const sig = buf.readUInt32LE(pos);
    if (sig === 0x04034b50) { // Local file header
      const method = buf.readUInt16LE(pos + 8);
      const compSize = buf.readUInt32LE(pos + 18);
      const uncompSize = buf.readUInt32LE(pos + 22);
      const nameLen = buf.readUInt16LE(pos + 26);
      const extraLen = buf.readUInt16LE(pos + 28);
      const name = buf.toString('utf8', pos + 30, pos + 30 + nameLen);
      const dataStart = pos + 30 + nameLen + extraLen;
      const compData = buf.subarray(dataStart, dataStart + compSize);
      
      let data;
      if (method === 0) {
        data = compData;
      } else if (method === 8) {
        data = zlib.inflateRawSync(compData);
      }
      if (data && name.endsWith('.json')) {
        entries.push({ name, data: data.toString('utf8') });
      }
      pos = dataStart + compSize;
    } else {
      pos++;
    }
  }
  return entries;
}

const entries = readZip('assets/bible_bundles/en/KJV.zip');
console.log(`Successfully parsed KJV.zip: found ${entries.length} chapter files!`);
if (entries.length > 0) {
  console.log('Sample file:', entries[0].name);
  const sample = JSON.parse(entries[0].data);
  console.log('Metadata:', sample.metadata);
  console.log('Verse 1:', sample.verses?.[0]);
}
