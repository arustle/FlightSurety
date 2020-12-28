import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async () => {

  let result = null;


  let contract = new Contract('localhost', () => {

    // Read transaction
    contract.isOperational((error, result) => {
      console.log(error, result);
      display('Operational Status', 'Check if contract is operational', [{
        label: 'Operational Status',
        error: error,
        value: result
      }]);
    });


    // User-submitted transaction
    DOM.elid('submit-oracle').addEventListener('click', () => {
      const flightId = DOM.elid('flight-select').value;
      // Write transaction
      contract.fetchFlightStatus(flightId, (error, result, payload) => {
        display('Oracles', 'Trigger oracles', [{
          label: 'Fetch Flight Status',
          error: error,
          value: payload.flight + ' ' + payload.timestamp
        }]);
      });
    })


    DOM.elid('buy-insurance').addEventListener('click', () => {
      const flightId = DOM.elid('flight-select').value;
      const insuranceCost = DOM.elid('insurance-cost').value;

      contract.buyInsurance(flightId, insuranceCost, (error, result) => {
        display('Contract', 'Buy Insurance', [{
          label: 'Bought Insurance',
          error: error,
          value: result
        }]);
      });
    });


    DOM.elid('withdraw-insurance-payout').addEventListener('click', () => {
      const flightId = DOM.elid('flight-select').value;


      contract.withdraw(flightId, (error, result) => {
        console.log('withdraw-insurance-payout', error, result)
        display('Contract', 'Withdraw payout', [{
          label: 'Withdraw payout',
          error: error,
          value: result
        }]);
      });
    });


    contract.flightSuretyApp.events.FlightStatusInfo({
      fromBlock: 0
    }, function (error, result) {
      console.log("FlightStatusInfo");
      if (error) {
        console.log(error)
      } else {
        console.log("[----- FlightStatusInfo", result);
      }
    });

    contract.flightSuretyApp.events.PaidPassenger({
      fromBlock: 0
    }, function (error, result) {
      console.log("PaidPassenger", error, result);
      display('Passenger', 'PaidPassenger', [{
        label: 'PaidPassenger',
        error: error,
        value: result
      }]);
    });

  });


  fetch('http://localhost:3000/flights', {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    },
  })
    .then(res => (res.json()))
    .then((res) => {
      contract.flights = res.flights.map(x => (Object.assign({}, x, {
        timestamp: new Date(x.timestamp)
      })));
      const flightSelector = document.getElementById('flight-select');

      contract.flights.forEach(flight => {
        const option = document.createElement('option');
        option.value = flight.id;
        option.text = `${flight.flight} @ ${flight.timestamp.toUTCString()}`;

        flightSelector.add(option);
      });
    })
})();


function display(title, description, results) {
  let displayDiv = DOM.elid("display-wrapper");
  let section = DOM.section();
  section.appendChild(DOM.h2(title));
  section.appendChild(DOM.h5(description));
  results.map((result) => {
    let row = section.appendChild(DOM.div({className: 'row'}));
    row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
    row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
    section.appendChild(row);
  })
  displayDiv.append(section);

}







