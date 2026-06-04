import fs from "fs";
import readline from "readline";
import { DynamoDBClient, BatchWriteItemCommand } from "@aws-sdk/client-dynamodb";

const TABLE_NAME = process.env.GEO_LOCATION_TABLE || "NativeFormsGeoLocations";
const dynamoClient = new DynamoDBClient({ region: process.env.AWS_REGION || "eu-north-1" });
const WRITE_CONCURRENCY = Math.max(1, Number(process.env.GEO_IMPORT_WRITE_CONCURRENCY || 12));

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function normalizeSearchText(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function toAttributeValue(value) {
  if (value === null || value === undefined) return { NULL: true };
  if (typeof value === "number") return { N: String(value) };
  if (typeof value === "boolean") return { BOOL: value };
  return { S: String(value) };
}

function marshallItem(item) {
  return Object.fromEntries(Object.entries(item).map(([key, value]) => [key, toAttributeValue(value)]));
}

async function batchWrite(items) {
  const chunks = [];
  for (let index = 0; index < items.length; index += 25) {
    chunks.push(items.slice(index, index + 25));
  }
  let cursor = 0;
  async function writeChunk(chunk) {
    let requestItems = {
      [TABLE_NAME]: chunk.map((Item) => ({
        PutRequest: { Item: marshallItem(Item) }
      }))
    };
    do {
      const result = await dynamoClient.send(new BatchWriteItemCommand({ RequestItems: requestItems }));
      requestItems = result.UnprocessedItems && Object.keys(result.UnprocessedItems).length
        ? result.UnprocessedItems
        : null;
      if (requestItems) {
        await sleep(250);
      }
    } while (requestItems);
  }
  async function worker() {
    while (cursor < chunks.length) {
      const chunk = chunks[cursor];
      cursor += 1;
      await writeChunk(chunk);
    }
  }
  await Promise.all(Array.from({ length: Math.min(WRITE_CONCURRENCY, chunks.length) }, worker));
}

async function readCountryNames(countryInfoPath) {
  const countries = new Map();
  const stream = readline.createInterface({
    input: fs.createReadStream(countryInfoPath, { encoding: "utf8" }),
    crlfDelay: Infinity
  });
  for await (const line of stream) {
    if (!line || line.startsWith("#")) continue;
    const parts = line.split("\t");
    const code = parts[0];
    const name = parts[4];
    if (/^[A-Z]{2}$/.test(code) && name) {
      countries.set(code, name);
    }
  }
  return countries;
}

async function readAdmin1Names(admin1Path) {
  const regions = new Map();
  const stream = readline.createInterface({
    input: fs.createReadStream(admin1Path, { encoding: "utf8" }),
    crlfDelay: Infinity
  });
  for await (const line of stream) {
    if (!line) continue;
    const parts = line.split("\t");
    const [countryCode, regionCode] = String(parts[0] || "").split(".");
    const name = parts[1] || parts[2] || "";
    if (countryCode && regionCode && name) {
      regions.set(`${countryCode}.${regionCode}`, name);
    }
  }
  return regions;
}

async function importLocations({ countryInfoPath, admin1Path, citiesPath }) {
  const countries = await readCountryNames(countryInfoPath);
  const regions = await readAdmin1Names(admin1Path);
  const countryItems = [...countries.entries()].flatMap(([countryCode, countryName]) => {
    const base = {
      locationPartition: "country",
      kind: "country",
      countryCode,
      countryName,
      label: countryName,
      displayLabel: countryName
    };
    return [
      { ...base, searchKey: `${normalizeSearchText(countryName)}#${countryCode}` },
      { ...base, searchKey: `${normalizeSearchText(countryCode)}#${countryCode}` }
    ];
  });
  await batchWrite(countryItems);

  const regionItems = [...regions.entries()].map(([key, regionName]) => {
    const [countryCode, regionCode] = key.split(".");
    const countryName = countries.get(countryCode) || countryCode;
    return {
      locationPartition: `region#${countryCode}`,
      searchKey: `${normalizeSearchText(regionName)}#${regionCode}`,
      kind: "region",
      countryCode,
      countryName,
      regionCode,
      regionName,
      label: `${regionName}, ${countryName}`,
      displayLabel: `${regionName}, ${countryName}`
    };
  });
  await batchWrite(regionItems);

  const stream = readline.createInterface({
    input: fs.createReadStream(citiesPath, { encoding: "utf8" }),
    crlfDelay: Infinity
  });
  let cityBuffer = [];
  for await (const line of stream) {
    if (!line) continue;
    const parts = line.split("\t");
    const geoNameId = parts[0];
    const cityName = parts[1];
    const latitude = Number(parts[4]);
    const longitude = Number(parts[5]);
    const countryCode = parts[8];
    const regionCode = parts[10] || "";
    const population = Number(parts[14]);
    if (!geoNameId || !cityName || !countryCode) continue;
    const countryName = countries.get(countryCode) || countryCode;
    const regionName = regions.get(`${countryCode}.${regionCode}`) || "";
    const displayLabel = [cityName, regionName, countryName].filter(Boolean).join(", ");
    const base = {
      searchKey: `${normalizeSearchText(cityName)}#${geoNameId}`,
      kind: "city",
      countryCode,
      countryName,
      regionCode,
      regionName,
      cityName,
      geoNameId,
      latitude: Number.isFinite(latitude) ? latitude : null,
      longitude: Number.isFinite(longitude) ? longitude : null,
      population: Number.isFinite(population) ? population : 0,
      label: displayLabel,
      displayLabel
    };
    cityBuffer.push({ ...base, locationPartition: `city#${countryCode}` });
    if (regionCode) {
      cityBuffer.push({ ...base, locationPartition: `city#${countryCode}#${regionCode}` });
    }
    if (cityBuffer.length >= 1000) {
      await batchWrite(cityBuffer);
      cityBuffer = [];
    }
  }
  if (cityBuffer.length) {
    await batchWrite(cityBuffer);
  }
}

const [countryInfoPath, admin1Path, citiesPath] = process.argv.slice(2);
if (!countryInfoPath || !admin1Path || !citiesPath) {
  console.error("Usage: node AWS/import-geonames-locations.mjs countryInfo.txt admin1CodesASCII.txt cities500.txt");
  process.exit(1);
}

await importLocations({ countryInfoPath, admin1Path, citiesPath });
