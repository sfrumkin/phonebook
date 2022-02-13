global.fetch = require('node-fetch');
const AmazonCognitoIdentity = require('amazon-cognito-identity-js-with-node-fetch');
const CognitoUserPool = AmazonCognitoIdentity.CognitoUserPool;
const AWS = require('aws-sdk');
const request = require('request');
const jwkToPem = require('jwk-to-pem');
const jwt = require('jsonwebtoken');
import commonMiddleware from '../lib/commonMiddleware';


const poolData = {    
  UserPoolId : process.env.COGNITO_USER_POOL_ID, // Your user pool id here    
  ClientId : process.env.COGNITO_POOL_CLIENT_ID // Your client id here
  }; 
const pool_region = process.env.REGION;

const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);

async function signin(event, context) {

  const {password, username} = event.body;
  console.log("Pool Data: " + poolData.UserPoolId + " " + poolData.ClientId + " " + pool_region);
  console.log("Login user: " + username);
  try{
    const userToken = await Login(username, password);
    console.log("After login user: " + username);
    return {
      statusCode: 200,
      body: JSON.stringify({token: userToken})
      
    };
  }
  catch (err)
  {
    console.log(err);
    return {
      statusCode: 501,
      body: JSON.stringify({})
    };
  }
}

function Login(username, password) {
  var authenticationDetails = new AmazonCognitoIdentity.AuthenticationDetails({
      Username : username,
      Password : password,
  });

  var userData = {
      Username : username,
      Pool : userPool
  };
  var cognitoUser = new AmazonCognitoIdentity.CognitoUser(userData);
  console.log('In login: '+ userData.Username + ' ' + userData.Pool)
  return new Promise((resolve, reject) => (
    cognitoUser.authenticateUser(authenticationDetails, {
      onSuccess: function (result) {
          console.log('success');
          console.log('access token + ' + result.getAccessToken().getJwtToken());
          console.log('id token + ' + result.getIdToken().getJwtToken());
          console.log('refresh token + ' + result.getRefreshToken().getToken());
          resolve(result.getIdToken().getJwtToken());
      },
      onFailure: function(err) {
          console.log(err);
          reject(err);
      },

    })
  ));
}

export const handler = commonMiddleware(signin);