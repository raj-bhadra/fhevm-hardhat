import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { ethers, fhevm } from "hardhat";
import { ConfidentialTokenWrapper, ConfidentialTokenWrapper__factory } from "../types";
import { ConfidentialTokenFactory, ConfidentialTokenFactory__factory } from "../types";
import { ConfidentialToken } from "../types";
import { USDC, USDC__factory } from "../types";
import { ZBondingCurve, ZBondingCurve__factory } from "../types";
import { expect } from "chai";
import { FhevmType } from "@fhevm/hardhat-plugin";

type Signers = {
  deployer: HardhatEthersSigner;
  alice: HardhatEthersSigner;
  bob: HardhatEthersSigner;
};

const baseAssetTokenName = "Base";
const baseAssetTokenSymbol = "BASE";
const baseAssetTokenContractURI = "https://base.com";

async function deployFixture() {
  const usdcFactory = (await ethers.getContractFactory("USDC")) as USDC__factory;
  const usdcContract = (await usdcFactory.deploy()) as USDC;
  const usdcContractAddress = await usdcContract.getAddress();

  const confidentialTokenWrapperFactory = (await ethers.getContractFactory(
    "ConfidentialTokenWrapper",
  )) as ConfidentialTokenWrapper__factory;
  const zUsdcContract = (await confidentialTokenWrapperFactory.deploy(usdcContract)) as ConfidentialTokenWrapper;
  const zUsdcContractAddress = await zUsdcContract.getAddress();

  const confidentialTokenFactoryFactory = (await ethers.getContractFactory(
    "ConfidentialTokenFactory",
  )) as ConfidentialTokenFactory__factory;
  const confidentialTokenFactoryContract = (await confidentialTokenFactoryFactory.deploy()) as ConfidentialTokenFactory;
  const confidentialTokenFactoryContractAddress = await confidentialTokenFactoryContract.getAddress();

  const txResponse = await confidentialTokenFactoryContract.createToken(
    baseAssetTokenName,
    baseAssetTokenSymbol,
    baseAssetTokenContractURI,
  );
  await txResponse.wait();
  const tokenAddresses = await confidentialTokenFactoryContract.getTokenAddresses();
  const baseAssetTokenContractAddress = tokenAddresses[0];
  const baseAssetTokenContract = await ethers.getContractAt("ConfidentialToken", baseAssetTokenContractAddress);

  const zBondingCurveFactory = (await ethers.getContractFactory("ZBondingCurve")) as ZBondingCurve__factory;
  const zBondingCurveContract = (await zBondingCurveFactory.deploy(
    zUsdcContract,
    confidentialTokenFactoryContract,
  )) as ZBondingCurve;
  const zBondingCurveContractAddress = await zBondingCurveContract.getAddress();

  return {
    usdcContract,
    usdcContractAddress,
    zUsdcContract,
    zUsdcContractAddress,
    confidentialTokenFactoryContract,
    confidentialTokenFactoryContractAddress,
    baseAssetTokenContractAddress,
    baseAssetTokenContract,
    zBondingCurveContract,
    zBondingCurveContractAddress,
  };
}

describe("ZBondingCurve", function () {
  let signers: Signers;
  let usdcContract: USDC;
  let zUsdcContract: ConfidentialTokenWrapper;
  let zUsdcContractAddress: string;
  let confidentialTokenFactoryContractAddress: string;
  let baseAssetTokenContract: ConfidentialToken;
  let baseAssetTokenContractAddress: string;
  let zBondingCurveContract: ZBondingCurve;
  let zBondingCurveContractAddress: string;

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

    ({
      usdcContract,
      zUsdcContract,
      zUsdcContractAddress,
      confidentialTokenFactoryContractAddress,
      baseAssetTokenContractAddress,
      baseAssetTokenContract,
      zBondingCurveContract,
      zBondingCurveContractAddress,
    } = await deployFixture());
  });

  it("should be initialized with correct parameters", async function () {
    const quoteAssetToken = await zBondingCurveContract.getQuoteAssetToken();
    expect(quoteAssetToken).to.eq(zUsdcContractAddress);
    const confidentialTokenFactory = await zBondingCurveContract.getConfidentialTokenFactory();
    expect(confidentialTokenFactory).to.eq(confidentialTokenFactoryContractAddress);
  });

  it("should allow buying base asset token with quote asset token", async function () {
    const usdcAmountIn = BigInt(3e6);
    const expectedBaseAssetTokenAmountOut = BigInt(3e6);
    const mintUsdcTx = await usdcContract["mint(address,uint256)"](signers.alice.address, usdcAmountIn);
    await mintUsdcTx.wait();

    // set allowance for wrapper contract to spend alice's usdc
    const approveTx = await usdcContract.connect(signers.alice).approve(zUsdcContractAddress, usdcAmountIn);
    await approveTx.wait();
    const wrapUsdcTx = await zUsdcContract.connect(signers.alice).wrap(signers.alice.address, usdcAmountIn);
    await wrapUsdcTx.wait();

    // set zbonding curve contract as operator for base asset token and zusdc token
    const maxUint48 = BigInt(2) ** BigInt(48) - BigInt(1);
    const setOperatorForBaseAssetTx = await baseAssetTokenContract
      .connect(signers.alice)
      .setOperator(zBondingCurveContractAddress, maxUint48);
    await setOperatorForBaseAssetTx.wait();
    const setOperatorForZUsdcTx = await zUsdcContract
      .connect(signers.alice)
      .setOperator(zBondingCurveContractAddress, maxUint48);
    await setOperatorForZUsdcTx.wait();

    // set zbonding curve contract as observer for base asset token and zusdc token
    const setObserverForBaseAssetTx = await baseAssetTokenContract
      .connect(signers.alice)
      .setObserver(signers.alice.address, zBondingCurveContractAddress);
    await setObserverForBaseAssetTx.wait();
    const setObserverForZUsdcTx = await zUsdcContract
      .connect(signers.alice)
      .setObserver(signers.alice.address, zBondingCurveContractAddress);
    await setObserverForZUsdcTx.wait();

    const encryptedTradeInputs = await fhevm
      .createEncryptedInput(zBondingCurveContractAddress, signers.alice.address)
      .add64(usdcAmountIn)
      .add64(0)
      .encrypt();

    const tradeTx = await zBondingCurveContract
      .connect(signers.alice)
      .trade(
        baseAssetTokenContract,
        encryptedTradeInputs.handles[0],
        encryptedTradeInputs.handles[1],
        encryptedTradeInputs.inputProof,
      );
    await tradeTx.wait();

    const encryptedBaseAssetTokenBalance = await baseAssetTokenContract
      .connect(signers.alice)
      .confidentialBalanceOf(signers.alice.address);
    const baseAssetTokenBalance = await fhevm.userDecryptEuint(
      FhevmType.euint64,
      encryptedBaseAssetTokenBalance,
      baseAssetTokenContractAddress,
      signers.alice,
    );
    expect(baseAssetTokenBalance).to.eq(expectedBaseAssetTokenAmountOut);
    const encryptedUsdcBalance = await zUsdcContract
      .connect(signers.alice)
      .confidentialBalanceOf(signers.alice.address);
    const usdcBalance = await fhevm.userDecryptEuint(
      FhevmType.euint64,
      encryptedUsdcBalance,
      zUsdcContractAddress,
      signers.alice,
    );
    expect(usdcBalance).to.eq(0);
  });

  it("should allow selling base asset token for quote asset token", async function () {
    const usdcAmountIn = BigInt(3e6);
    const expectedBaseAssetTokenAmountOut = BigInt(3e6);
    const mintUsdcTx = await usdcContract["mint(address,uint256)"](signers.alice.address, usdcAmountIn);
    await mintUsdcTx.wait();

    // set allowance for wrapper contract to spend alice's usdc
    const approveTx = await usdcContract.connect(signers.alice).approve(zUsdcContractAddress, usdcAmountIn);
    await approveTx.wait();
    const wrapUsdcTx = await zUsdcContract.connect(signers.alice).wrap(signers.alice.address, usdcAmountIn);
    await wrapUsdcTx.wait();

    // set zbonding curve contract as operator for base asset token and zusdc token
    const maxUint48 = BigInt(2) ** BigInt(48) - BigInt(1);
    const setOperatorForBaseAssetTx = await baseAssetTokenContract
      .connect(signers.alice)
      .setOperator(zBondingCurveContractAddress, maxUint48);
    await setOperatorForBaseAssetTx.wait();
    const setOperatorForZUsdcTx = await zUsdcContract
      .connect(signers.alice)
      .setOperator(zBondingCurveContractAddress, maxUint48);
    await setOperatorForZUsdcTx.wait();

    // set zbonding curve contract as observer for base asset token and zusdc token
    const setObserverForBaseAssetTx = await baseAssetTokenContract
      .connect(signers.alice)
      .setObserver(signers.alice.address, zBondingCurveContractAddress);
    await setObserverForBaseAssetTx.wait();
    const setObserverForZUsdcTx = await zUsdcContract
      .connect(signers.alice)
      .setObserver(signers.alice.address, zBondingCurveContractAddress);
    await setObserverForZUsdcTx.wait();

    const encryptedTradeInputs = await fhevm
      .createEncryptedInput(zBondingCurveContractAddress, signers.alice.address)
      .add64(usdcAmountIn)
      .add64(0)
      .encrypt();

    const buyTradeTx = await zBondingCurveContract
      .connect(signers.alice)
      .trade(
        baseAssetTokenContract,
        encryptedTradeInputs.handles[0],
        encryptedTradeInputs.handles[1],
        encryptedTradeInputs.inputProof,
      );
    await buyTradeTx.wait();

    const encryptedBaseAssetTokenBalance = await baseAssetTokenContract
      .connect(signers.alice)
      .confidentialBalanceOf(signers.alice.address);
    const baseAssetTokenBalance = await fhevm.userDecryptEuint(
      FhevmType.euint64,
      encryptedBaseAssetTokenBalance,
      baseAssetTokenContractAddress,
      signers.alice,
    );
    expect(baseAssetTokenBalance).to.eq(expectedBaseAssetTokenAmountOut);
    const encryptedUsdcBalance = await zUsdcContract
      .connect(signers.alice)
      .confidentialBalanceOf(signers.alice.address);
    const usdcBalance = await fhevm.userDecryptEuint(
      FhevmType.euint64,
      encryptedUsdcBalance,
      zUsdcContractAddress,
      signers.alice,
    );
    expect(usdcBalance).to.eq(0);

    const encryptedSellTradeInputs = await fhevm
      .createEncryptedInput(zBondingCurveContractAddress, signers.alice.address)
      .add64(0)
      .add64(expectedBaseAssetTokenAmountOut)
      .encrypt();

    const sellTradeTx = await zBondingCurveContract
      .connect(signers.alice)
      .trade(
        baseAssetTokenContract,
        encryptedSellTradeInputs.handles[0],
        encryptedSellTradeInputs.handles[1],
        encryptedSellTradeInputs.inputProof,
      );
    await sellTradeTx.wait();

    const encryptedBaseAssetTokenBalanceAfterSell = await baseAssetTokenContract
      .connect(signers.alice)
      .confidentialBalanceOf(signers.alice.address);
    const baseAssetTokenBalanceAfterSell = await fhevm.userDecryptEuint(
      FhevmType.euint64,
      encryptedBaseAssetTokenBalanceAfterSell,
      baseAssetTokenContractAddress,
      signers.alice,
    );
    expect(baseAssetTokenBalanceAfterSell).to.eq(0);
    const encryptedUsdcBalanceAfterSell = await zUsdcContract
      .connect(signers.alice)
      .confidentialBalanceOf(signers.alice.address);
    const usdcBalanceAfterSell = await fhevm.userDecryptEuint(
      FhevmType.euint64,
      encryptedUsdcBalanceAfterSell,
      zUsdcContractAddress,
      signers.alice,
    );
    expect(usdcBalanceAfterSell).to.eq(usdcAmountIn);
  });
});
