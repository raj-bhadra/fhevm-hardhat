import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { ethers, fhevm } from "hardhat";
import { TestToken, TestToken__factory } from "../types";
import { ConfidentialTokenWrapper, ConfidentialTokenWrapper__factory } from "../types";
import { expect } from "chai";
import { FhevmType } from "@fhevm/hardhat-plugin";

type Signers = {
  deployer: HardhatEthersSigner;
  alice: HardhatEthersSigner;
  bob: HardhatEthersSigner;
};

async function deployFixture() {
  const underlyingFactory = (await ethers.getContractFactory("TestToken")) as TestToken__factory;
  const underlying = (await underlyingFactory.deploy(BigInt(1e18))) as TestToken;
  const underlyingAddress = await underlying.getAddress();
  const factory = (await ethers.getContractFactory("ConfidentialTokenWrapper")) as ConfidentialTokenWrapper__factory;
  const confidentialTokenWrapperContract = (await factory.deploy(underlying)) as ConfidentialTokenWrapper;
  const confidentialTokenWrapperAddress = await confidentialTokenWrapperContract.getAddress();
  return { underlying, underlyingAddress, confidentialTokenWrapperContract, confidentialTokenWrapperAddress };
}

describe("ConfidentialTokenWrapper", function () {
  let signers: Signers;
  let confidentialTokenWrapperContract: ConfidentialTokenWrapper;
  let confidentialTokenWrapperAddress: string;
  let underlying: TestToken;

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

    ({ underlying, confidentialTokenWrapperContract, confidentialTokenWrapperAddress } = await deployFixture());
  });

  it("should able to get underlying name", async function () {
    const name = await confidentialTokenWrapperContract.name();
    expect(name).to.eq("zTest Token");
  });

  it("should able to get underlying symbol", async function () {
    const symbol = await confidentialTokenWrapperContract.symbol();
    expect(symbol).to.eq("zTT");
  });

  it("should able to wrap tokens", async function () {
    const wrapAmount = BigInt(1e18);
    const transferTx = await underlying.transfer(signers.alice.address, wrapAmount);
    await transferTx.wait();
    // approve wrapper to spend using alice
    const approveTx = await underlying.connect(signers.alice).approve(confidentialTokenWrapperAddress, wrapAmount);
    await approveTx.wait();
    // wrap tokens using alice
    const wrapTx = await confidentialTokenWrapperContract
      .connect(signers.alice)
      .wrap(signers.alice.address, wrapAmount);
    await wrapTx.wait();
    // get balance of alice
    const balance = await confidentialTokenWrapperContract
      .connect(signers.alice)
      .confidentialBalanceOf(signers.alice.address);
    const clearBalance = await fhevm.userDecryptEuint(
      FhevmType.euint64,
      balance,
      confidentialTokenWrapperAddress,
      signers.alice,
    );
    expect(clearBalance).to.eq(BigInt(1e6));
  });

  it("should be able to unwrap tokens", async function () {
    const wrapAmount = BigInt(1e18);
    // lesser due to uint64 being used in erc 7984 tokens
    const expectedWrappedBalance = BigInt(1e6);
    const transferTx = await underlying.transfer(signers.alice.address, wrapAmount);
    await transferTx.wait();
    // approve wrapper to spend using alice
    const approveTx = await underlying.connect(signers.alice).approve(confidentialTokenWrapperAddress, wrapAmount);
    await approveTx.wait();
    // wrap tokens using alice
    const wrapTx = await confidentialTokenWrapperContract
      .connect(signers.alice)
      .wrap(signers.alice.address, wrapAmount);
    await wrapTx.wait();
    // get balance of alice
    const balance = await confidentialTokenWrapperContract
      .connect(signers.alice)
      .confidentialBalanceOf(signers.alice.address);
    const clearBalance = await fhevm.userDecryptEuint(
      FhevmType.euint64,
      balance,
      confidentialTokenWrapperAddress,
      signers.alice,
    );
    expect(clearBalance).to.eq(expectedWrappedBalance);
    const unwrapAmount = BigInt(1e3);
    const encryptedUnwrapAmount = await fhevm
      .createEncryptedInput(confidentialTokenWrapperAddress, signers.alice.address)
      .add64(unwrapAmount)
      .encrypt();
    const unwrapTx = await confidentialTokenWrapperContract
      .connect(signers.alice)
      [
        "unwrap(address,address,bytes32,bytes)"
      ](signers.alice.address, signers.alice.address, encryptedUnwrapAmount.handles[0], encryptedUnwrapAmount.inputProof);
    await unwrapTx.wait();
    // get balance of alice
    const balanceAfterUnwrap = await confidentialTokenWrapperContract
      .connect(signers.alice)
      .confidentialBalanceOf(signers.alice.address);
    const clearBalanceAfterUnwrap = await fhevm.userDecryptEuint(
      FhevmType.euint64,
      balanceAfterUnwrap,
      confidentialTokenWrapperAddress,
      signers.alice,
    );
    expect(clearBalanceAfterUnwrap).to.eq(expectedWrappedBalance - unwrapAmount);
  });
});
