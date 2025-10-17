import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { ethers, fhevm } from "hardhat";
import { ConfidentialToken, ConfidentialToken__factory } from "../types";
import { expect } from "chai";
import { FhevmType } from "@fhevm/hardhat-plugin";

type Signers = {
  deployer: HardhatEthersSigner;
  alice: HardhatEthersSigner;
  bob: HardhatEthersSigner;
};

const name = "Test Token";
const symbol = "TT";
const contractURI = "https://test.com";

async function deployFixture() {
  const factory = (await ethers.getContractFactory("ConfidentialToken")) as ConfidentialToken__factory;
  const confidentialTokenContract = (await factory.deploy(name, symbol, contractURI)) as ConfidentialToken;
  const confidentialTokenAddress = await confidentialTokenContract.getAddress();
  return { confidentialTokenContract, confidentialTokenAddress };
}

describe("ConfidentialTokenFactory", function () {
  let signers: Signers;
  let confidentialTokenContract: ConfidentialToken;
  let confidentialTokenAddress: string;

  before(async function () {
    const ethSigners: HardhatEthersSigner[] = await ethers.getSigners();
    signers = { deployer: ethSigners[0], alice: ethSigners[1], bob: ethSigners[2] };
  });

  beforeEach(async function () {
    // Check whether the tests are running against an FHEVM mock environment
    if (!fhevm.isMock) {
      console.warn(`This hardhat test suite cannot run on Sepolia Testnet`);
      this.skip();
    }

    ({ confidentialTokenContract, confidentialTokenAddress } = await deployFixture());
  });

  it("should be able to mint tokens", async function () {
    const mintAmount = 1000;
    const encryptedMintAmount = await fhevm
      .createEncryptedInput(confidentialTokenAddress, signers.alice.address)
      .add64(mintAmount)
      .encrypt();
    const tx = await confidentialTokenContract
      .connect(signers.alice)
      .mint(signers.alice.address, encryptedMintAmount.handles[0], encryptedMintAmount.inputProof);
    await tx.wait();
    const balance = await confidentialTokenContract.confidentialBalanceOf(signers.alice.address);
    const clearBalance = await fhevm.userDecryptEuint(
      FhevmType.euint64,
      balance,
      confidentialTokenAddress,
      signers.alice,
    );
    expect(clearBalance).to.eq(mintAmount);
  });
});
