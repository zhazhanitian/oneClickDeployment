const swaggerAutogen = require('swagger-autogen')();

const outputFile = './swagger.yaml'; // 输出文件
const endpointsFiles = ['./src/routes/admin/depart.route.ts']; // 路由文件

const doc = {
  info: {
    title: 'API Title',
    description: 'API Description',
  },
  host: 'localhost:3000',
  basePath: '/api',
};

swaggerAutogen(outputFile, endpointsFiles, doc).then(() => {
  console.log('生成成功');
});
