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

async function signup(event, context) {

  const {email, password, username} = event.body;
  console.log("Pool Data: " + poolData.UserPoolId + " " + poolData.ClientId + " " + pool_region);
  console.log("Registering user: " + email);
  try{
    await RegisterUser(email, password, username);
    console.log("After registering user: " + email);
    return {
      statusCode: 200,
      body: JSON.stringify({})
    };
  }
  catch (err)
  {
    console.log(err);
    return {
      statusCode: 401,
      body: JSON.stringify({})
    };
  }
}

function RegisterUser(email, password, username){
  var attributeList = [];
 
  var dataEmail = {
      Name : 'email',
      Value : email
  };

  var attributeEmail = new AmazonCognitoIdentity.CognitoUserAttribute(dataEmail);

  attributeList.push(attributeEmail);

  return new Promise((resolve, reject) => (
    userPool.signUp(username, password, attributeList, null, (err, result) => {
      if (err) {
        reject(err);
        return;
      }

      resolve(result.user);
    })
  ));
 
}
export const handler = commonMiddleware(signup);