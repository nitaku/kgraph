# kgraph usage

If not installed, install redis:

  sudo apt-get install redis-cli
  sudo apt-get install redis-tools
  sudo apt-get install redis-server

and pm2:

  sudo apt-get install pm2

Create a redis channel:
  
  redis-cli subscribe kgraph

Setup the repository:

  git clone https://github.com/nitaku/kgraph.git
  cd kgraph
  npm install

Start kgraph using pm2:
  
  pm2 start server.js --name "kgraph"
  