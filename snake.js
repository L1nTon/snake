console.clear()
const H = 45, W = 100;
const sleep = (n) => new Promise(prot => setTimeout(prot, n));

const fs = require('fs');
const readline = require('node:readline');
let bread = [Math.floor(Math.random()*H), Math.floor(Math.random()*W)];
let snake = [[4,5],[5,5],[6,5]];
let score = 0;
let isRunning = true;
let move_X = 0, move_Y = -1;
const directions = {
    'up':    { x: 0,  y: -1 },
    'down':  { x: 0,  y: 1  },
    'left':  { x: -1, y: 0  },
    'right': { x: 1,  y: 0  }
};
let currentDir = 'up';
const opposites = {
    'up': 'down',
    'down': 'up',
    'left': 'right',
    'right': 'left'
};

function setupInput() {
    readline.emitKeypressEvents(process.stdin);
    if (process.stdin.isTTY) process.stdin.setRawMode(true);

    process.stdin.on('keypress', (str, key) => {
        const newDir = key.name;
        if (key.ctrl && key.name === 'c') {
            saveGame();
            process.exit();
        }
        if (directions[newDir] && newDir !== opposites[currentDir]) {
            currentDir = newDir;
            move_X = directions[newDir].x;
            move_Y = directions[newDir].y;
        }
    });
}

function saveGame() {
    const data = {
        snake,
        bread,
        score,
        currentDir,
        move_X,
        move_Y
    };

    fs.writeFileSync('game.json', JSON.stringify(data, null, 2));
}

function loadGame(){
    if (fs.existsSync('game.json')) {
        const raw = fs.readFileSync('game.json');
        const data = JSON.parse(raw);

        snake = data.snake;
        bread = data.bread;
        score = data.score;
        currentDir = data.currentDir;
        move_X = data.move_X;
        move_Y = data.move_Y;

        return true;
    }
    return false;
}

async function askToLoad() {
    if (!fs.existsSync('game.json')) return;

    console.log("Найдена сохранённая игра. Загрузить? (y/n)");

    process.stdin.setRawMode(false);

    return new Promise(resolve => {
        process.stdin.once('data', (data) => {
            const answer = data.toString().trim().toLowerCase();
            resolve(answer === 'y');
        });
    });
}



var board = Array.from({ length: H }, () => Array(W).fill(0));
board[Math.floor(Math.random()*H)][Math.floor(Math.random()*W)] = 1;


function draw(snake, bread) {
    let output = "";

    for (let i = -1; i <= H; i++) {
        for (let j = -1; j <= W; j++) {
            if (i === -1 || i === H || j === -1 || j === W) {
                output += "#";
            } 
            else if (i === bread[0] && j === bread[1]) {
                output += "@";
            } 
            else {
                const isSnake = snake.some(seg => seg[0] === i && seg[1] === j);
                
                if (isSnake) {
                    const isHead = snake[0][0] === i && snake[0][1] === j;
                    output += isHead ? "Q" : "o";
                } else {
                    output += " "; 
                }
            }
        }
        output += "\n";
    }

    process.stdout.write("\x1b[H" + `Score: ${score}\n` + output);
}

function isBreadEaten(){
    return snake[0][0] == bread[0] && snake[0][1] == bread[1];
}
function breadRerender(){
    bread = [Math.floor(Math.random()*H), Math.floor(Math.random()*W)]
}
function snakeMoveHead(){
    let snakeHead = snake[0];
    let head_x = (snakeHead[1] + move_X) % W
    let head_y = (snakeHead[0] + move_Y) % H
    snake.unshift([head_y < 0 ? head_y + H : head_y, head_x < 0 ? head_x + W : head_x])

    if(isBreadEaten()){
        breadRerender();
        score++;
    }else snake.pop()
}

async function game() {
    console.clear();

    while (isRunning) {



        await sleep(100);

        snakeMoveHead();

        draw(snake, bread);



        // process.stdout.write('\x1b[H'); 
        
        // console.log(`Нажата клавиша: ${currentButton || 'нет'}`);
        // console.log(`Игровое поле ${W}x${H}...`);
    }
}


(async () => {
    const shouldLoad = await askToLoad();

    if (shouldLoad) {
        loadGame();
    }

    setupInput();
    game();
})()