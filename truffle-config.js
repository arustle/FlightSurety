var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      // provider: function () {
      //   return new HDWalletProvider(mnemonic, "http://127.0.0.1:7545/", 0, 50);
      // },
      network_id: '5777',
      gas: 4600000
      // gas: 9999999
    }
  },
  mocha: {
    timeout: 100000
  },
  compilers: {
    solc: {
      version: "^0.6.2"
    }
  }
};