import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';

var cors = require('cors')


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

const oracles = [];
const airlines = [];
const flights = [];


flightSuretyApp.events.OracleRequest({
  fromBlock: 0
}, async function (error, event) {
  if (error) console.log(error)
  console.log('OracleRequest', event);


  // ------------------------


  const requiredIndex = event.returnValues.index;
  const airline = event.returnValues.airline;
  const flight = event.returnValues.flight;
  const timestamp = event.returnValues.timestamp;

  const code = getRandomStatusCode();
  // const code = '20';
  const validOracles = oracles.filter(x => (x.indices.includes(requiredIndex)));
  // console.log('validOracles', validOracles)

  for (let i = 0; i < validOracles.length; i++) {
    const oracle = validOracles[i];

    try {
      await flightSuretyApp.methods.submitOracleResponse(
        requiredIndex,
        airline,
        flight,
        timestamp,
        code
      ).send({
        from: oracle.account,
        gas: 4712388,
        gasPrice: 100000000000
      });
      console.log(oracle.account, `${i + 1}/${validOracles.length}`, `CODE-${code}`, 'OK')
    } catch (e) {
      console.log(oracle.account, `${i + 1}/${validOracles.length}`, `CODE-${code}`, e.message)
    }

  }


})
;


function getRandomStatusCode() {

  // const STATUS_CODES = {
  //   UNKNOWN: 0,
  //   ON_TIME: 10,
  //   LATE_AIRLINE: 20,
  //   LATE_WEATHER: 30,
  //   LATE_TECHNICAL: 40,
  //   LATE_OTHER: 50,
  // };

  return (Math.floor(Math.random() * 6)).toString();

}

async function registerOracles(wantedOracleCount) {

  const accounts = await web3.eth.getAccounts();
  const feeWei = await flightSuretyApp.methods.REGISTRATION_FEE().call();

  let i = 10;
  while (oracles.length <= wantedOracleCount && i < accounts.length) {
    const account = accounts[i];
    let indices;
    let action = '';
    try {
      indices = await flightSuretyApp.methods.getMyIndexes().call({
        from: account,
      });
      action = 'Found';
    } catch {
      await flightSuretyApp.methods.registerOracle().send({
        from: account,
        value: feeWei,
        gas: 4712388,
        gasPrice: 100000000000
      });

      indices = await flightSuretyApp.methods.getMyIndexes().call({
        from: account
      });
      action = 'Registered';
    }

    oracles.push({
      account,
      indices
    });

    i++;
    console.log(`${action} Oracle: ${oracles.length}, ${account}`)
  }

}

async function registerAirlines() {
  const accounts = await web3.eth.getAccounts();
  const priceWei = (web3.utils.toWei('10')).toString();

  const owner = accounts[0];
  let i = 1;

  while (airlines.length < 5) {
    const account = accounts[i];
    try {
      await flightSuretyApp.methods
        .registerAirline(
          account
        )
        .send({
          from: owner,
          gas: 4712388,
          gasPrice: 100000000000
        });
    } catch (e) {
      console.log('registerAirline', e.message)
    }
    try {
      await flightSuretyApp.methods
        .fund(
          account
        )
        .send({
          from: account,
          value: priceWei,
          gas: 4712388,
          gasPrice: 100000000000
        });
      console.log('fund', 'OK')
    } catch (e) {
      console.log('fund', e.message)
    }

    airlines.push(account);
    i++;
  }
}

async function registerFlights() {

  for (let i = 0; i < airlines.length; i++) {
    const airline = airlines[i];
    const flight = {
      id: String(i),
      airline: airline,
      flight: `Flight ${i}`,
      timestamp: new Date(Date.now() + 1000 * 60 * 60 * i)
    };


    try {
      await flightSuretyApp.methods
        .registerFlight(
          flight.airline,
          flight.flight,
          Math.floor(flight.timestamp / 1000)
        )
        .send({
          from: flight.airline,
          gas: 4712388,
          gasPrice: 100000000000
        });

      flights.push(flight);
    } catch (e) {
      console.log('registerFlight', e.message)
    }
  }


}

registerAirlines()
  .then(() => (console.log("Registered Airlines")))
  .then(registerFlights)
  .then(() => (console.log("Registered Flights")))
  .then(() => {
    return registerOracles(21);
  })
  .then(() => (console.log("Registered Oracles")))

// -------------------------------------------

const app = express();
app.use(cors());
app.get('/api', (req, res) => {
  res.send({
    message: 'An API for use with your Dapp!'
  })
})


app.get('/flights', (req, res) => {

  return res.status(200).json({
    flights,
  });
})

export default app;


