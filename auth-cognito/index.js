global.fetch = require('node-fetch');
const AmazonCognitoIdentity = require('amazon-cognito-identity-js-with-node-fetch');
const CognitoUserPool = AmazonCognitoIdentity.CognitoUserPool;
const AWS = require('aws-sdk');
const request = require('request');
const jwkToPem = require('jwk-to-pem');
const jwt = require('jsonwebtoken');


const poolData = {    
  UserPoolId : process.env.COGNITO_USER_POOL_ID, // Your user pool id here    
  ClientId : process.env.COGNITO_POOL_CLIENT_ID // Your client id here
  }; 
const pool_region = process.env.AWS_REGION;

const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);

async function signup(event, context) {

  const {email, password} = event.body;

  RegisterUser(email, password);

  return {
    statusCode: 201,
    body: {}
  };

}

function RegisterUser(email, password){
  var attributeList = [];
  attributeList.push(new AmazonCognitoIdentity.CognitoUserAttribute({Name:"email",Value:"sampleEmail@gmail.com"}));

  userPool.signUp(email, password, attributeList, null, function(err, result){
      if (err) {
          console.log(err);
          return;
      }
      console.log('in result: ' + result);
      cognitoUser = result.user;
      console.log('user name is ' + cognitoUser.getUsername());
  });
}


function ValidateToken(token) {
  request({
      url: `https://cognito-idp.${pool_region}.amazonaws.com/${poolData.UserPoolId}/.well-known/jwks.json`,
      json: true
  }, function (error, response, body) {
      if (!error && response.statusCode === 200) {
          pems = {};
          var keys = body['keys'];
          for(var i = 0; i < keys.length; i++) {
              //Convert each key to PEM
              var key_id = keys[i].kid;
              var modulus = keys[i].n;
              var exponent = keys[i].e;
              var key_type = keys[i].kty;
              var jwk = { kty: key_type, n: modulus, e: exponent};
              var pem = jwkToPem(jwk);
              pems[key_id] = pem;
          }
          //validate the token
          var decodedJwt = jwt.decode(token, {complete: true});
          if (!decodedJwt) {
              console.log("Not a valid JWT token");
              return;
          }

          var kid = decodedJwt.header.kid;
          var pem = pems[kid];
          if (!pem) {
              console.log('Invalid token');
              return;
          }

          jwt.verify(token, pem, function(err, payload) {
              if(err) {
                  console.log("Invalid Token.");
              } else {
                  console.log("Valid Token.");
                  console.log(payload);
              }
          });
      } else {
          console.log("Error! Unable to download JWKs");
      }
  });
}

function renew() {
  const RefreshToken = new AmazonCognitoIdentity.CognitoRefreshToken({RefreshToken: "your_refresh_token_from_a_previous_login"});

  const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);

  const userData = {
      Username: "sample@gmail.com",
      Pool: userPool
  };

  const cognitoUser = new AmazonCognitoIdentity.CognitoUser(userData);

  cognitoUser.refreshSession(RefreshToken, (err, session) => {
      if (err) {
          console.log(err);
      } else {
          let retObj = {
              "access_token": session.accessToken.jwtToken,
              "id_token": session.idToken.jwtToken,
              "refresh_token": session.refreshToken.token,
          }
          console.log(retObj);
      }
  })
}

function DeleteUser() {
  var authenticationDetails = new AmazonCognitoIdentity.AuthenticationDetails({
      Username: username,
      Password: password,
  });

  var userData = {
      Username: username,
      Pool: userPool
  };
  var cognitoUser = new AmazonCognitoIdentity.CognitoUser(userData);

  cognitoUser.authenticateUser(authenticationDetails, {
      onSuccess: function (result) {
          cognitoUser.deleteUser((err, result) => {
              if (err) {
                  console.log(err);
              } else {
                  console.log("Successfully deleted the user.");
                  console.log(result);
              }
          });
      },
      onFailure: function (err) {
          console.log(err);
      },
  });
}

export const handler = signup;

