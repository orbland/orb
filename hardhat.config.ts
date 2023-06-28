import fs from "fs"
import "@nomicfoundation/hardhat-toolbox"
import "@nomiclabs/hardhat-solhint"
import "@openzeppelin/hardhat-upgrades"
import "@typechain/hardhat"
import { HardhatUserConfig } from "hardhat/config"
import "hardhat-contract-sizer"
import "hardhat-gas-reporter"
import "hardhat-preprocessor"
import "solidity-coverage"

import * as dotenv from "dotenv"
dotenv.config()

function getRemappings() {
    return fs
        .readFileSync("remappings.txt", "utf8")
        .split("\n")
        .filter(Boolean)
        .map((line) => line.trim().split("="))
}

const coinmarketcapKey: string | undefined = process.env.CMC_API_KEY

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.20",
        settings: {
            optimizer: {
                enabled: true,
                runs: 20_000,
            },
        },
    },
    paths: {
        sources: "./src", // Use ./src rather than ./contracts as Hardhat expects
        cache: "./cache_hardhat", // Use a different cache for Hardhat than Foundry
    },
    defaultNetwork: "localhost",
    networks: {
        hardhat: {
            mining: {
                auto: true,
                interval: [3000, 6000],
            },
        },
        goerli: {
            url: `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
            accounts: [process.env.DEPLOYER_PRIVATE_KEY as string],
        },
    },
    etherscan: {
        apiKey: process.env.ETHERSCAN_API_KEY,
    },
    gasReporter: {
        enabled: true,
        currency: "USD",
        coinmarketcap: coinmarketcapKey,
    },
    // This fully resolves paths for imports in the ./lib directory for Hardhat
    preprocess: {
        eachLine: (hre) => ({
            transform: (line: string) => {
                if (line.match(/^\s*import /i)) {
                    getRemappings().forEach(([find, replace]) => {
                        if (line.match(find)) {
                            line = line.replace(find, replace)
                        }
                    })
                }
                return line
            },
        }),
    },
}

export default config