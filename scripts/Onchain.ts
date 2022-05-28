import { Signer } from "ethers";
import { isBytesLike } from "ethers/lib/utils";
import { ethers, network } from "hardhat";
import { OnChainNFT } from "../typechain";
const fs = require("fs");

async function main() {
  const signers = await ethers.getSigners();
  const Contract = await ethers.getContractFactory("OnChainNFT");
  // const contract = await Contract.deploy();
  const CHUNK_SIZE = 24575;

  const contract = await ethers.getContractFactory(
    "OnChainNFT",

    signers[0]
  );
  const c = (await contract.deploy()) as OnChainNFT;
  await c.deployed();
  console.log(c.address);
  // READ INPUT FILE AND CONVERT TO BYTES
  let bytes: Uint8Array[] = [];
  let svg = ethers.utils.toUtf8Bytes(fs.readFileSync(`../leogold.svg`, "utf8"));

  // CHUNK IT
  for (let i = 0; i < svg.length / CHUNK_SIZE; i++) {
    const end =
      (i + 1) * CHUNK_SIZE < svg.length ? (i + 1) * CHUNK_SIZE : svg.length;
    bytes.push(svg.slice(i * CHUNK_SIZE, end));
  }
  console.log(bytes.length);

  // SAVE IT
  for (let i = 0; i < bytes.length; i++) {
    let tx = await c.saveData("Gold", i, bytes[i], {
      gasLimit: 10_000_000,
    });
    await tx.wait();
    console.log("Page " + i + " saved");
  }

  // GET IT
  console.log(await c.balanceOf(signers[0].address));

  // const data = await c.tokenURI(0)
  // console.log(data)
  // fs.writeFileSync('./Output.svg', ethers.utils.toUtf8String(data))
  await new Promise((f) => setTimeout(f, 10000));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
