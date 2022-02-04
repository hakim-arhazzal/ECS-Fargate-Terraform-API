const app = require('express')();

const PORT = 8080;

app.listen(
    PORT,
    () => console.log(`it's live on http://localhost:${PORT}`)
)

app.get('/version', (req,res) => {
    res.status(200).send({
       version: "2.0.0"
    })
 }
)
