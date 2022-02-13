const schema = {
  type: 'object', 
  properties: {
    body: {
      type: 'object', 
      properties: {
        name: {
          type: 'string',
        },
        phone: {
          type: 'string',
        },
      },
      required: ['name'],
      required: ['phone'],
    },
  },
  required: [
    'body',
  ],
};

export default schema;