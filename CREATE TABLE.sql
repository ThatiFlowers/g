-- Criar tabela usuarios
CREATE TABLE usuarios (
    id_usuario INTEGER PRIMARY KEY AUTOINCREMENT,
    nome TEXT NOT NULL,
    cpf_cnpj TEXT UNIQUE,
    contato TEXT
);

-- Criar tabela livros
CREATE TABLE livros (
    id_livro INTEGER PRIMARY KEY AUTOINCREMENT,
    titulo TEXT NOT NULL,
    autor TEXT,
    ano_publicacao INTEGER,
    isbn TEXT UNIQUE,
    quantidade INTEGER NOT NULL
);

-- Criar tabela emprestimos
CREATE TABLE emprestimos (
    id_emprestimo INTEGER PRIMARY KEY AUTOINCREMENT,
    id_usuario INTEGER NOT NULL,
    id_livro INTEGER NOT NULL,
    data_emprestimo DATE NOT NULL,
    data_prevista_devolucao DATE NOT NULL,
    data_devolucao DATE,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
    FOREIGN KEY (id_livro) REFERENCES livros(id_livro)
);




-- Inserir usuários
INSERT INTO usuarios (nome, cpf_cnpj, contato) VALUES ('Ana', '12345678901', 'ana@email.com');
INSERT INTO usuarios (nome, cpf_cnpj, contato) VALUES ('João', '23456789012', 'joao@email.com');
INSERT INTO usuarios (nome, cpf_cnpj, contato) VALUES ('Jolie', '34567890123', 'jolie@email.com');
INSERT INTO usuarios (nome, cpf_cnpj, contato) VALUES ('Pedro', '45678901234', 'pedro@email.com');
INSERT INTO usuarios (nome, cpf_cnpj, contato) VALUES ('Lucas', '56789012345', 'lucas@email.com');

-- Inserir livros
INSERT INTO livros (titulo, autor, ano_publicacao, quantidade) VALUES ('Dom Casmurro', 'Machado de Assis', 1899, 3);
INSERT INTO livros (titulo, autor, ano_publicacao, quantidade) VALUES ('O Pequeno Príncipe', 'Antoine de Saint-Exupéry', 1943, 2);
INSERT INTO livros (titulo, autor, ano_publicacao, quantidade) VALUES ('A Arte da Guerra', 'Sun Tzu', -500, 1);
INSERT INTO livros (titulo, autor, ano_publicacao, quantidade) VALUES ('Romeu e Julieta', 'William Shakespeare', 1597, 2);
INSERT INTO livros (titulo, autor, ano_publicacao, quantidade) VALUES ('Hamlet', 'William Shakespeare', 1600, 2);


-- Mostra apenas livros com pelo menos 1 unidade disponível.
SELECT COUNT(*) 
FROM emprestimos
WHERE id_usuario = 1
AND data_devolucao IS NULL;

-- Ajuda a decidir qual livro o usuário pode pegar.

SELECT id_livro, titulo, autor, quantidade
FROM livros
WHERE quantidade > 0;


from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import sqlite3
from datetime import date, timedelta

app = FastAPI(title="Biblioteca Completa API")

--- banco de dados
DB_PATH = "biblioteca.db"

# ----- Modelos -----
class Usuario(BaseModel):
    nome: str
    cpf_cnpj: str
    contato: str

class Livro(BaseModel):
    titulo: str
    autor: str
    ano_publicacao: int
    isbn: str
    quantidade: int

class Emprestimo(BaseModel):
    id_usuario: int
    id_livro: int

# ----- Conexão com o banco -----
def get_conn():
    return sqlite3.connect(DB_PATH)

# ----- Inicialização do banco -----
def init_db():
    with get_conn() as conn:
        cursor = conn.cursor()
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS usuarios (
            id_usuario INTEGER PRIMARY KEY AUTOINCREMENT,
            nome TEXT NOT NULL,
            cpf_cnpj TEXT UNIQUE,
            contato TEXT,
            bloqueado_ate DATE
        );""")
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS livros (
            id_livro INTEGER PRIMARY KEY AUTOINCREMENT,
            titulo TEXT NOT NULL,
            autor TEXT,
            ano_publicacao INTEGER,
            isbn TEXT UNIQUE,
            quantidade INTEGER NOT NULL
        );""")
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS emprestimos (
            id_emprestimo INTEGER PRIMARY KEY AUTOINCREMENT,
            id_usuario INTEGER NOT NULL,
            id_livro INTEGER NOT NULL,
            data_emprestimo DATE NOT NULL,
            data_prevista_devolucao DATE NOT NULL,
            data_devolucao DATE,
            FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
            FOREIGN KEY (id_livro) REFERENCES livros(id_livro)
        );""")
        conn.commit()

init_db()


--- CRUD USUÁRIOS


@app.post("/usuarios")
def criar_usuario(usuario: Usuario):
    with get_conn() as conn:
        cursor = conn.cursor()
        try:
            cursor.execute("INSERT INTO usuarios (nome, cpf_cnpj, contato) VALUES (?, ?, ?);",
                           (usuario.nome, usuario.cpf_cnpj, usuario.contato))
            conn.commit()
            return {"msg": "Usuário cadastrado com sucesso."}
        except sqlite3.IntegrityError:
            raise HTTPException(status_code=400, detail="CPF/CNPJ já cadastrado.")

@app.get("/usuarios")
def listar_usuarios():
    with get_conn() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM usuarios;")
        return {"usuarios": cursor.fetchall()}

@app.get("/usuarios/{id_usuario}")
def obter_usuario(id_usuario: int):
    with get_conn() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM usuarios WHERE id_usuario=?", (id_usuario,))
        usuario = cursor.fetchone()
        if not usuario:
            raise HTTPException(status_code=404, detail="Usuário não encontrado.")
        return {"usuario": usuario}

@app.put("/usuarios/{id_usuario}")
def atualizar_usuario(id_usuario: int, usuario: Usuario):
    with get_conn() as conn:
        cursor = conn.cursor()
        cursor.execute("UPDATE usuarios SET nome=?, cpf_cnpj=?, contato=? WHERE id_usuario=?",
                       (usuario.nome, usuario.cpf_cnpj, usuario.contato, id_usuario))
        conn.commit()
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Usuário não encontrado.")
        return {"msg": "Usuário atualizado."}

@app.delete("/usuarios/{id_usuario}")
def deletar_usuario(id_usuario: int):
    with get_conn() as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM usuarios WHERE id_usuario=?", (id_usuario,))
        conn.commit()
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Usuário não encontrado.")
        return {"msg": "Usuário deletado."}

@app.get("/usuarios_bloqueados")
def usuarios_bloqueados():
    hoje = date.today().isoformat()
    with get_conn() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM usuarios WHERE bloqueado_ate >= ?", (hoje,))
        return {"usuarios_bloqueados": cursor.fetchall()}


--- CRUD LIVROS

@app.post("/livros")
def criar_livro(livro: Livro):
    with get_conn() as conn:
        cursor = conn.cursor()
        try:
            cursor.execute("""
            INSERT INTO livros (titulo, autor, ano_publicacao, isbn, quantidade)
            VALUES (?, ?, ?, ?, ?)""",
                           (livro.titulo, livro.autor, livro.ano_publicacao, livro.isbn, livro.quantidade))
            conn.commit()
            return {"msg": "Livro cadastrado com sucesso."}
        except sqlite3.IntegrityError:
            raise HTTPException(status_code=400, detail="ISBN já cadastrado.")

@app.get("/livros")
def listar_livros():
    with get_conn() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM livros;")
        return {"livros": cursor.fetchall()}

@app.get("/livros/{id_livro}")
def obter_livro(id_livro: int):
    with get_conn() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM livros WHERE id_livro=?", (id_livro,))
        livro = cursor.fetchone()
        if not livro:
            raise HTTPException(status_code=404, detail="Livro não encontrado.")
        return {"livro": livro}

@app.put("/livros/{id_livro}")
def atualizar_livro(id_livro: int, livro: Livro):
    with get_conn() as conn:
        cursor = conn.cursor()
        cursor.execute("""
        UPDATE livros SET titulo=?, autor=?, ano_publicacao=?, isbn=?, quantidade=? WHERE id_livro=?
        """, (livro.titulo, livro.autor, livro.ano_publicacao, livro.isbn, livro.quantidade, id_livro))
        conn.commit()
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Livro não encontrado.")
        return {"msg": "Livro atualizado."}

@app.delete("/livros/{id_livro}")
def deletar_livro(id_livro: int):
    with get_conn() as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM livros WHERE id_livro=?", (id_livro,))
        conn.commit()
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Livro não encontrado.")
        return {"msg": "Livro deletado."}


--- CRUD EMPRÉSTIMOS


@app.post("/emprestimos")
def criar_emprestimo(emprestimo: Emprestimo):
    hoje = date.today()
    with get_conn() as conn:
        cursor = conn.cursor()
        
        # Verificar bloqueio
        cursor.execute("SELECT bloqueado_ate FROM usuarios WHERE id_usuario=?", (emprestimo.id_usuario,))
        bloqueio = cursor.fetchone()
        if bloqueio and bloqueio[0] and bloqueio[0] >= hoje.isoformat():
            raise HTTPException(status_code=400, detail="Usuário bloqueado.")

        # Limite 3 livros
        cursor.execute("SELECT COUNT(*) FROM emprestimos WHERE id_usuario=? AND data_devolucao IS NULL;", (emprestimo.id_usuario,))
        if cursor.fetchone()[0] >= 3:
            raise HTTPException(status_code=400, detail="Usuário já possui 3 livros.")

        # Quantidade disponível
        cursor.execute("SELECT quantidade FROM livros WHERE id_livro=?", (emprestimo.id_livro,))
        qtd = cursor.fetchone()
        if not qtd or qtd[0] <= 0:
            raise HTTPException(status_code=400, detail="Livro indisponível.")

        data_prevista = hoje + timedelta(days=5)
        cursor.execute("""
        INSERT INTO emprestimos (id_usuario, id_livro, data_emprestimo, data_prevista_devolucao)
        VALUES (?, ?, ?, ?)""",
                       (emprestimo.id_usuario, emprestimo.id_livro, hoje, data_prevista))
        cursor.execute("UPDATE livros SET quantidade = quantidade - 1 WHERE id_livro=?", (emprestimo.id_livro,))
        conn.commit()
        return {"msg": "Empréstimo registrado."}

@app.get("/emprestimos")
def listar_emprestimos():
    with get_conn() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM emprestimos;")
        return {"emprestimos": cursor.fetchall()}

@app.put("/emprestimos/devolver/{id_emprestimo}")
def devolver_livro(id_emprestimo: int):
    hoje = date.today()
    with get_conn() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT id_livro, data_prevista_devolucao, id_usuario FROM emprestimos WHERE id_emprestimo=?", (id_emprestimo,))
        res = cursor.fetchone()
        if not res:
            raise HTTPException(status_code=404, detail="Empréstimo não encontrado.")

        id_livro, data_prevista, id_usuario = res
        cursor.execute("UPDATE emprestimos SET data_devolucao=? WHERE id_emprestimo=?", (hoje, id_emprestimo))
        cursor.execute("UPDATE livros SET quantidade = quantidade + 1 WHERE id_livro=?", (id_livro,))

        # Bloqueio se atrasado
        if hoje > date.fromisoformat(data_prevista):
            bloqueio_ate = hoje + timedelta(days=7)
            cursor.execute("UPDATE usuarios SET bloqueado_ate=? WHERE id_usuario=?", (bloqueio_ate, id_usuario))

        conn.commit()
        return {"msg": "Livro devolvido."}

@app.delete("/emprestimos/{id_emprestimo}")
def deletar_emprestimo(id_emprestimo: int):
    with get_conn() as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM emprestimos WHERE id_emprestimo=?", (id_emprestimo,))
        conn.commit()
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Empréstimo não encontrado.")
        return {"msg": "Empréstimo deletado."}

@app.get("/livros_por_usuario/{id_usuario}")
def livros_por_usuario(id_usuario: int):
    with get_conn() as conn:
        cursor = conn.cursor()
        cursor.execute("""
        SELECT l.id_livro, l.titulo, e.data_emprestimo, e.data_prevista_devolucao, e.data_devolucao
        FROM emprestimos e
        JOIN livros l ON e.id_livro = l.id_livro
        WHERE e.id_usuario=?
        """, (id_usuario,))



from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import sqlite3
from datetime import date, timedelta

app = FastAPI(title="Biblioteca Completa API")

DB_PATH = "biblioteca.db"

# ----- Modelos -----
class Usuario(BaseModel):
    nome: str
    cpf_cnpj: str
    contato: str

class Livro(BaseModel):
    titulo: str
    autor: str
    ano_publicacao: int
    isbn: str
    quantidade: int

class Emprestimo(BaseModel):
    id_usuario: int
    id_livro: int

# ----- Conexão com o banco -----
def get_conn():
    return sqlite3.connect(DB_PATH)

# ----- Inicialização do banco -----
def init_db():
    with get_conn() as conn:
        cursor = conn.cursor()
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS usuarios (
            id_usuario INTEGER PRIMARY KEY AUTOINCREMENT,
            nome TEXT NOT NULL,
            cpf_cnpj TEXT UNIQUE,
            contato TEXT,
            bloqueado_ate DATE
        );""")
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS livros (
            id_livro INTEGER PRIMARY KEY AUTOINCREMENT,
            titulo TEXT NOT NULL,
            autor TEXT,
            ano_publicacao INTEGER,
            isbn TEXT UNIQUE,
            quantidade INTEGER NOT NULL
        );""")
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS emprestimos (
            id_emprestimo INTEGER PRIMARY KEY AUTOINCREMENT,
            id_usuario INTEGER NOT NULL,
            id_livro INTEGER NOT NULL,
            data_emprestimo DATE NOT NULL,
            data_prevista_devolucao DATE NOT NULL,
            data_devolucao DATE,
            FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
            FOREIGN KEY (id_livro) REFERENCES livros(id_livro)
        );""")
        conn.commit()

init_db()



-



