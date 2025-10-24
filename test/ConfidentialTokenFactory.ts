import { ethers, fhevm } from "hardhat";
import { ConfidentialTokenFactory, ConfidentialTokenFactory__factory } from "../types";
import { expect } from "chai";

async function deployFixture() {
  const factory = (await ethers.getContractFactory("ConfidentialTokenFactory")) as ConfidentialTokenFactory__factory;
  const confidentialTokenFactoryContract = (await factory.deploy()) as ConfidentialTokenFactory;
  const confidentialTokenFactoryAddress = await confidentialTokenFactoryContract.getAddress();
  return { confidentialTokenFactoryContract, confidentialTokenFactoryAddress };
}

describe("ConfidentialTokenFactory", function () {
  let confidentialTokenFactoryContract: ConfidentialTokenFactory;

  beforeEach(async function () {
    // Check whether the tests are running against an FHEVM mock environment
    if (!fhevm.isMock) {
      console.warn(`This hardhat test suite cannot run on Sepolia Testnet`);
      this.skip();
    }

    ({ confidentialTokenFactoryContract } = await deployFixture());
  });

  it("no tokens should be present after deployment", async function () {
    const tokenAddresses = await confidentialTokenFactoryContract.getTokenAddresses();
    expect(tokenAddresses.length).to.eq(0);
  });

  it("should create a new confidential token", async function () {
    const name = "Test Token";
    const symbol = "TT";
    const contractURI = "https://test.com";
    const txResponse = await confidentialTokenFactoryContract.createToken(name, symbol, contractURI);
    const txReceipt = await txResponse.wait();
    const event = txReceipt?.logs?.find((log) => {
      try {
        const decoded = confidentialTokenFactoryContract.interface.parseLog(log);
        return decoded?.name === "TokenCreated";
      } catch {
        return false;
      }
    });
    const decodedEvent = confidentialTokenFactoryContract.interface.parseLog(event!);
    const tokenAddress = decodedEvent?.args?.tokenAddress;
    const tokenAddresses = await confidentialTokenFactoryContract.getTokenAddresses();
    expect(tokenAddresses.length).to.eq(1);
    expect(tokenAddresses[0]).to.eq(tokenAddress);
    const tokenContract = await ethers.getContractAt("ConfidentialToken", tokenAddress);
    expect(await tokenContract.name()).to.eq(name);
    expect(await tokenContract.symbol()).to.eq(symbol);
    expect(await tokenContract.contractURI()).to.eq(contractURI);
  });
});
