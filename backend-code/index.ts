import express, { Express, Request, Response } from 'express';
import serverless from 'serverless-http';

const app: Express = express();
const port = 5000;

app.get('/hello', (req: Request, res: Response) => {
    res.send('Express + TypeScript Server');
});

app.listen(port, () => {
    console.log(`⚡️[server]: Server is running at http://localhost:${port}`);
});

module.exports.handler = serverless(app);