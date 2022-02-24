import http from 'k6/http';
import {check, group, sleep, fail } from 'k6';
import { Counter, Trend } from 'k6/metrics';
import { parseHTML } from 'k6/html';

const BASE_URL = 'https://e6hje6oy5g.execute-api.us-east-1.amazonaws.com/serverless_lambda_stage';
const DEBUG = true;

const start = Date.now();

const ExecutionType = {
  load:   'load',
  smoke:  'smoke',
  stress: 'stress',
  soak:   'soak'
}

var Execution = 'load'; 
var ExecutionOptions_Scenarios;

switch(Execution){
    case ExecutionType.load:
        ExecutionOptions_Scenarios = {
            BackendFlow_scenario: {
                exec: 'BackendFlowTest',
                duration: '30s',
                vus: 100,
                executor: 'constant-vus'
            },
            AccountSetupDelete_scenario: {
              exec: 'AccountSetupDelete',
              duration: '30s',
              vus: 200,
              executor: 'constant-vus'
          }
        }; 
        break; // end case ExecutionType.load    
  }


export let options ={
    scenarios: ExecutionOptions_Scenarios,
    thresholds: {
        http_req_failed: ['rate<0.05'],   
        //'http_req_duration': ['p(95)<500', 'p(99)<1500'],
        'http_req_duration{name:Create}': ['avg<600', 'max<2000']       
    }
};


function randomString(length) {
  const charset = 'abcdefghijklmnopqrstuvwxyz';
  let res = '';
  while (length--) res += charset[Math.random() * charset.length | 0];
  
  return res;
}

function formatDate(date) {
  var hours = date.getHours();
  var minutes = date.getMinutes();
  var ampm = hours >= 12 ? 'pm' : 'am';
  hours = hours % 12;
  hours = hours ? hours : 12; // the hour '0' should be '12'
  minutes = minutes < 10 ? '0'+ minutes : minutes;
  var strTime = hours + ':' + minutes + ' ' + ampm;
  return (date.getMonth()+1) + "/" + date.getDate() + "/" + date.getFullYear() + "  " + strTime;
}

function DebugOrLog(textToLog){
  if (DEBUG){
      var millis = Date.now() - start; // we get the ms ellapsed from the start of the test
      var time = Math.floor(millis / 1000); // in seconds
      // console.log(`${time}se: ${textToLog}`); // se = Seconds elapsed
      console.log(`${textToLog}`); 
  }
}


// Testing the backend with an end-to-end workflow (essentially the advanced API Flow sample at https://k6.io/docs/examples/advanced-api-flow/)
export function BackendFlowTest(authToken){
  const requestConfigWithTag = tag => ({
    headers: {
      Authorization: `Bearer ${authToken}`,
      'Content-Type': 'application/json'
    },
    tags: Object.assign({}, {
      name: 'PrivateCrocs'
    }, tag)
  });
  group('Create contacts', () => {
    let URL = `${BASE_URL}/contacts`;
    let tempName=randomString(10);
    let tempPhone=randomString(9);
  
  
    group('Create contacts', () => {
      const payload = {
        name: `${tempName}`,
        phone: `${tempPhone}`,
      };
      //console.log(tempName + ' ' + tempPhone);
      const res = http.post(URL, JSON.stringify(payload),  requestConfigWithTag({ name: 'Create' }));

      if (check(res, { 'Contact created correctly': (r) => r.status === 201 })) {
        URL = `${URL}/${tempName}`;
        //URL = `${URL}/Timmothy`;
        
      } else {
        DebugOrLog(`Unable to create a Contact ${URL} ${res.status} ${res.body}`);

        return;
      }
    });

    group('Get contact', () => {

      const res = http.get(URL, requestConfigWithTag({ name: 'Get' }));
      const isSuccessfulGet = check(res, {
        'Get worked': () => res.status === 200,
        'name is correct': () => res.json('pk') === 'CONTACT_'+tempName,
      });

      if (!isSuccessfulGet) {
        DebugOrLog(`Unable to get the contact ${URL} ${res.status} ${res.body}`);
        return
      }
    });

    group('Delete contact', () => {
      const delRes = http.del(URL, null,  requestConfigWithTag({ name: 'Delete' }));

      const isSuccessfulDelete = check(null, {
        'Contact was deleted correctly': () => delRes.status === 200,
      });

      if (!isSuccessfulDelete) {
          DebugOrLog(`Contact was not deleted properly`);
        return;
      }
    });
  });

  //sleep(1);
}

export function AccountSetupDelete() {

   // register a new user and authenticate via a Bearer token.
  let user = `${randomString(10)}`;
  let authToken;

  group('Signup user', () => {
    let res = http.post(`${BASE_URL}/accounts`, JSON.stringify({
      email: user + '@example.com',
      username: user,
      password: 'ABCabc123!',
    }), {headers: {
        'Content-Type': 'application/json'
    }}); 

    const isSuccessfulRequest = check(res, { 
        'created user': (r) => r.status === 201 
    }); //201 = created
  });

  group('Signin user', () => {
      
    let loginRes = http.post(`${BASE_URL}/signin`, JSON.stringify({
      username: user,
      password: 'ABCabc123!'
    }),{
      headers: {
      'Content-Type': 'application/json'
    }});
    
    const isSuccessfulLogin = check(loginRes, { 
      'login user': (r) => r.status === 200 
    }); 
    
    authToken = loginRes.json('token');
    let logInSuccessful = check(authToken, { 
        'logged in successfully': () => authToken !== '', 
    });

  });

  group('Delete user', () => {
    let delRes = http.del(`${BASE_URL}/accounts`, JSON.stringify({
      email: user + '@example.com',
      username: user,
      password: 'ABCabc123!',
    }), {headers: {
        Authorization: `Bearer ${authToken}`,
        'Content-Type': 'application/json'
    }}); 

    const isSuccessfulDel = check(delRes, { 
      'delete user': (r) => r.status === 200 
    }); 
  });  
 
}
// setup configuration
export function setup() {
  DebugOrLog(`== SETUP BEGIN ===========================================================`)
  // log the date & time start of the test
  DebugOrLog(`Start of test: ${formatDate(new Date())}`)

  // log the test type
  DebugOrLog(`Test executed: ${Execution}`)

   // register a new user and authenticate via a Bearer token.
  let user = `${randomString(10)}`;
  let res = http.post(`${BASE_URL}/accounts`, JSON.stringify({
    email: user + '@example.com',
    username: user,
    password: 'ABCabc123!',
  }), {headers: {
      'Content-Type': 'application/json'
  }}); 

  const isSuccessfulRequest = check(res, { 
      'created user': (r) => r.status === 201 
  }); //201 = created

  if (isSuccessfulRequest){
      DebugOrLog(`The user ${user} was created successfully!`);
  }
  else {
      DebugOrLog(`There was a problem creating the user ${user}. It might be existing, so please modify it on the executor bat file`);
      DebugOrLog(`The http status is ${res.status}`);        
      DebugOrLog(`The http error is ${res.error}`);        
  }

  let loginRes = http.post(`${BASE_URL}/signin`, JSON.stringify({
    username: user,
    password: 'ABCabc123!'
  }),{
    headers: {
    'Content-Type': 'application/json'
  }});
  
  const isSuccessfulLogin = check(loginRes, { 
    'login user': (r) => r.status === 200 
  }); 
  
  if (isSuccessfulLogin){
    DebugOrLog(`The user ${user} was logged in successfully!`);
}
else {
    DebugOrLog(`There was a problem logging in the user ${user}. `);
    DebugOrLog(`The http status is ${res.status}`);        
    DebugOrLog(`The http error is ${res.error}`);        
}

  let authToken = loginRes.json('token');
  let logInSuccessful = check(authToken, { 
      'logged in successfully': () => authToken !== '', 
  });

  if (logInSuccessful){
      DebugOrLog(`Logged in successfully with the token.`); 
  }

   DebugOrLog(`== SETUP END ===========================================================`)
 
  return authToken; // this will be passed as parameter to all the exported functions
}