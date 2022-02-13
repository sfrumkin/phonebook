import {v4 as uuid} from 'uuid';
import AWS from 'aws-sdk';
import commonMiddleware from '../lib/commonMiddleware';
import createError from 'http-errors';
import validator from '@middy/validator';
import createContactSchema from '../lib/schemas/createContactSchema';

const dynamodb = new AWS.DynamoDB.DocumentClient();

async function createContact(event, context) {

  const {phone, name} = event.body;
  const {email} = event.requestContext.authorizer.claims;
  console.log('email: ' + email);

  const contact = {
    pk: 'CONTACT_'+ name,
    sk: 'ACCOUNT_'+email,
    data: phone,
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
    body: JSON.stringify(contact),
  };
}

export const handler = commonMiddleware(createContact).use(
  validator({
    inputSchema: createContactSchema,
    ajvOptions: {
      strict: false,
    },
  })
);

