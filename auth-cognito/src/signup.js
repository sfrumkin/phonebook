global.fetch = require('node-fetch');
const AmazonCognitoIdentity = require('amazon-cognito-identity-js-with-node-fetch');
const CognitoUserPool = AmazonCognitoIdentity.CognitoUserPool;
const AWS = require('aws-sdk');
const request = require('request');
const jwkToPem = require('jwk-to-pem');
const jwt = require('jsonwebtoken');
import commonMiddleware from '../lib/commonMiddleware';
import createError from 'http-errors';


const poolData = {    
  UserPoolId : process.env.COGNITO_USER_POOL_ID, // Your user pool id here    
  ClientId : process.env.COGNITO_POOL_CLIENT_ID // Your client id here
  }; 
const pool_region = process.env.REGION;

const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);

const dynamodb = new AWS.DynamoDB.DocumentClient();

async function signup(event, context) {

  const {email, password, username} = event.body;
  console.log("Pool Data: " + poolData.UserPoolId + " " + poolData.ClientId + " " + pool_region);
  console.log("Registering user: " + email);
  try{
    await RegisterUser(email, password, username);
    console.log("After registering user: " + email);
  }
  catch (err)
  {
    console.log(err);
    return {
      statusCode: 401,
      body: JSON.stringify({})
    };
  }

  const contact = {
    pk: 'ACCOUNT_'+email,
    sk: username,
  };
 
  try{
    await dynamodb.put({
      TableName: process.env.CONTACTS_TABLE_NAME,
      Item: contact,
    }).promise();
  } catch(error){
    console.error(error);
    throw new createError.InternalServerError(error);
  } 
  return {
    statusCode: 201,
    body: JSON.stringify(contact)
  };

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