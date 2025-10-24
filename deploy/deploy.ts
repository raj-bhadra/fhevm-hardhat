import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  const deployedFHECounter = await deploy("FHECounter", {
    from: deployer,
    log: true,
  });

  console.log(`FHECounter contract: `, deployedFHECounter.address);

  const deployedUsdc = await deploy("USDC", {
    from: deployer,
    log: true,
  });

  console.log(`USDC contract: `, deployedUsdc.address);

  const deployedConfidentialTokenWrapper = await deploy("ConfidentialTokenWrapper", {
    from: deployer,
    args: [deployedUsdc.address],
    log: true,
  });

  console.log(`ConfidentialTokenWrapper contract: `, deployedConfidentialTokenWrapper.address);

  const deployedConfidentialTokenFactory = await deploy("ConfidentialTokenFactory", {
    from: deployer,
    log: true,
  });

  console.log(`ConfidentialTokenFactory contract: `, deployedConfidentialTokenFactory.address);

  const deployedZBondingCurve = await deploy("ZBondingCurve", {
    from: deployer,
    args: [deployedConfidentialTokenWrapper.address, deployedConfidentialTokenFactory.address],
    log: true,
  });
  console.log(`ZBondingCurve contract: `, deployedZBondingCurve.address);
};
export default func;
func.id = "deploy_assets"; // id required to prevent reexecution
func.tags = ["FHECounter", "USDC", "ConfidentialTokenWrapper", "ConfidentialTokenFactory", "ZBondingCurve"];
