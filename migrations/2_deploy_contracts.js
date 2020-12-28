const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(FlightSuretyData);
  const dataContract = await FlightSuretyData.deployed();

  await deployer.deploy(FlightSuretyApp, dataContract.address);
  const appContract = await FlightSuretyApp.deployed();

  let config = {
    localhost: {
      url: 'http://localhost:7545',
      dataAddress: FlightSuretyData.address,
      appAddress: FlightSuretyApp.address
    }
  }
  fs.writeFileSync(__dirname + '/../src/dapp/config.json', JSON.stringify(config, null, '\t'), 'utf-8');
  fs.writeFileSync(__dirname + '/../src/server/config.json', JSON.stringify(config, null, '\t'), 'utf-8');
}