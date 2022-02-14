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

var cognitoUser;

async function deleteAccount(event, context) {

  const {password, username} = event.body;

  try{
    await DeleteUser(username, password);
    console.log("After first login user: " + username);
    await Delete();
    console.log("After delete user: " + username);
    return {
      statusCode: 200,
      body: JSON.stringify({})
      
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

function DeleteUser(username, password) {
  var authenticationDetails = new AmazonCognitoIdentity.AuthenticationDetails({
      Username : username,
      Password : password,
  });

  var userData = {
      Username : username,
      Pool : userPool
  };
  cognitoUser = new AmazonCognitoIdentity.CognitoUser(userData);
  console.log('In login: '+ userData.Username + ' ' + userData.Pool)
  return new Promise((resolve, reject) => (
    cognitoUser.authenticateUser(authenticationDetails, {
      onSuccess: function (result) {
          console.log('success');
          resolve();
      },
      onFailure: function(err) {
          console.log(err);
          reject(err);
      },

    })
  ));
}

function Delete()
{
  return new Promise((resolve, reject) => (
    cognitoUser.deleteUser( (err, result) => {
      if (err) {
        console.log('Could not delete user');
        console.log(err);
        reject(err);
      } else {
        console.log('Deleted user');
        resolve(result);
      }
    })
  ));
}
// function DeleteUser(username, password) {
//   var authenticationDetails = new AmazonCognitoIdentity.AuthenticationDetails({
//       Username : username,
//       Password : password,
//   });

//   var userData = {
//       Username : username,
//       Pool : userPool
//   };
//   var cognitoUser = new AmazonCognitoIdentity.CognitoUser(userData);
//   console.log('In DeleteUser: '+ userData.Username + ' ' + userData.Pool)
//   cognitoUser.deleteUser(function(err, result) {
//     if (err) {
//        console.log('Could not delete user');
//        console.log(err);
//     } else {
//        console.log('Deleted user');
//     }
//  });
// }

export const handler = commonMiddleware(deleteAccount);