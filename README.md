# D5Star

Biblioteca data-driven de criação de jogos em Godot 4.7. Tudo que o jogo
define vive em JSON; o código da engine é genérico e nunca sabe o nome de
nada específico de um jogo.

O nome vem do dado: o **d5\***, que mostra 0..5 e **explode nos dois
sentidos** — tirou 5, rola de novo e soma; tirou 0, rola de novo e subtrai.
Média 2,5, e as explosões se cancelam exatamente, então o dado é simétrico:
foge para cima com a mesma facilidade que foge para baixo. É o que permite ao
azarão vencer sem que ninguém tenha inclinado a régua a favor dele.

```gdscript
D5.roll(rng)                    # um d5*
D5.check(base, rng)             # base + 2d5*
D5.contest(ataque, defesa, rng) # margem: > 0 significa que o ataque venceu
D5.read(rng)                    # 2d5* lido duas vezes: total e estrelas (os 5 que somaram)
D5.against(base, 5, rng)        # contra uma dificuldade: margem, graus (margem ÷ 5) e estrelas
D5.versus(ataque, defesa, rng)  # a disputa com as estrelas de cada lado
```

Consumida como **git submodule** em `res://addons/d5star/`.

---

## Instalação

```bash
git submodule add https://github.com/Slaxis/d5star.git addons/d5star
git submodule update --init --recursive
```

Abra o projeto no Godot e habilite **D5Star** em `Project Settings > Plugins`.
O plugin, em `plugin/`, registra os sete autoloads na ordem correta — o jogo nunca escreve
essas linhas no `project.godot` à mão:

```
Air · Log · Drive · God · The · I18n · Radio
```

Depois de habilitado uma vez, as entradas ficam gravadas no `project.godot`;
builds headless e exportadas não precisam de nada.

Para clonar um jogo que já usa a lib:

```bash
git clone --recursive <url-do-jogo>
# ou, se já clonou sem --recursive:
git submodule update --init --recursive
```

Para atualizar a lib num jogo:

```bash
git submodule update --remote addons/d5star
git add addons/d5star && git commit -m "chore: bump d5star"
```

O jogo fica pinado no commit que você commitou. Nenhum update chega sozinho.

---

## Configuração

A lib carrega dois arquivos e faz merge, com o projeto sobrescrevendo:

**`addons/d5star/engine.json`** — layout interno da lib. Viaja com o
submodule; um jogo não mexe aqui.

**`res://d5star.json`** — layout do jogo. **Opcional**: todas as chaves têm
default, então um projeto novo boota sem criar o arquivo.

```json
{
  "game_root": "game",
  "modules": "modules",
  "defs": "defs",
  "user_modules": "user://modules",
  "module_manifest": "module.json",
  "content": "content",
  "system": "system",
  "game_config": "game",
  "scene_dir": "scene"
}
```

`engine_root` não é configurável: o `Drive` deriva a raiz da própria
localização do script, então a lib funciona de qualquer pasta.

O `d5star.json` também guarda o que é do jogo e não de um módulo, como a chroma
do jogo, `"chroma": "two_tone"` (veja *As cores dos sprites*, abaixo). O código
lê uma chave com `Drive.setting(chave, padrão)`.

Toda coisa embaixo de `content/things/` de um módulo diz o Def dela,
`"def": "<id>"`, nela ou no ancestral dela, e a pasta onde ela está não conta.
Um Def fornecido, um script do jogo com aquele id em `game/defs/`, recebe a
coisa se for um `KindDef`, o único Def que guarda coisas; sem script, a lib
infere um `KindDef`, uma tabela, que vive enquanto o módulo está ativo.
Qualquer outra coisa é erro, com o caminho do arquivo, em `Drive.def_errors()`,
e o `Game` não sobe: uma coisa com `"def": "rules"`, por exemplo, já que o
`RulesDef` lê o JSON dele inteiro e não guarda coisa.

A lib não fornece Def nenhum. Os fluxos de telas são coisas com
`"def": "flow"`, e o `Game` pega deles o fluxo que as regras nomeiam.

---

## Mods: o modelo do Caves of Qud

A lib foi pensada para mods do jeito do Caves of Qud: "o usuario prove `<thing>.json`, `<thing>.png` e `<thing>.gd` e vc tem a injeção de nova funcionalidade", nas
palavras do autor. Para cada coisa, um módulo traz até três arquivos com o id
dela no nome, em qualquer pasta do seu `content/`:

- `<id>.json`, os dados, sozinha ou numa lista de coisas;
- `<id>.png`, a imagem;
- `<id>.gd`, o comportamento: um script que estende `Thing`, ou `ThingPart`
  para uma parte, sem `class_name`.

`God.things.create(id)` monta a coisa a partir do script dela, com os dados.
As pastas de conteúdo vêm da maior prioridade para a menor, então um mod que
pede o jogo (`"requires"`) e traz um arquivo de mesmo nome toma o lugar do
arquivo do jogo. Só o conteúdo dá script a uma coisa: um script do projeto
fora dele não é de coisa nenhuma, qualquer que seja o nome. O
`ScriptBindingValidator` avisa no boot quando um `<id>.gd` não é do tipo da
coisa.

Um mod de usuário mora em `user://modules/<id>/`, com `module.json` e
`content/`. O script de um mod é código, e roda na máquina de quem instala o
mod, como no Qud.

O `<id>.png` de um mod de usuário fica numa pasta que o Godot não importa, e o
Godot 4 não carrega imagem que não importou: o `TextureLoader` lê essa imagem
como arquivo, e `God.media.texture(id)` a devolve como devolve a do jogo.

---

## As cores dos sprites: chroma e paleta

A lib serve a jogos que recolorem os sprites de jeitos diferentes: um com um tom
só, outro com quatro, outro com oito para um artista dedicado, com nomes como
`main`, `mid` e `hi` num jogo e `foreground` e `background` noutro. Por isso a
lib não sabe nenhuma cor: o jogo diz quais são, como dado (J141).

- Uma **chroma** diz com que cores-chave um jogo desenha os seus sprites:
  quantas, o nome de cada uma e o RGB.
- Pintar troca cada chave pela cor do nome dela. O pixel que não é chave fica
  como foi desenhado.
- Uma **paleta** é uma lista de cores com nome.
  - Uma chroma que aponta para uma paleta só aceita as cores dela, o jeito do
    Caves of Qud. Uma cor fora dela sai como erro no log, e pinta mesmo assim.
  - Uma chroma pode tirar as suas chaves de uma paleta. Pintar com outra paleta
    troca as chaves pela posição, como o modo indexed do Aseprite.
- O sprite diz qual chroma usa num campo `chroma`, dele ou do seu `ancestor`.
  Sem esse campo, vale a chroma do jogo, a que o `d5star.json` nomeia. Um jogo
  sem chroma pinta a imagem como foi desenhada.

```json
{ "id": "two_tone", "def": "chromas", "keys": { "main": "#ffffff", "second": "#808080" } }
{ "id": "qud", "def": "chromas", "keys": { "foreground": "#000000", "detail": "#ffffff" }, "palette": "qud_colors" }
{ "id": "nes", "def": "chromas", "keys": "nes_day" }
{ "id": "nes_day", "def": "palettes", "colors": { "sky": "#5c94fc", "brick": "#c84c0c" } }
```

```gdscript
God.media.paint("star", { "main": cor, "second": cor })   # a textura, guardada até o módulo mudar
God.media.paint("mario", "nes_night")                       # as cores de outra paleta, pela posição
God.media.painted("star", { "main": cor })                  # a imagem, nova, para montar com outras
God.media.chroma_of("star")                                 # a chroma do sprite, ou null
```

A chroma e a paleta são coisas do jogo, no tipo que ele quiser (`chromas` e
`palettes` acima). Cada uma nasce da classe da lib, `Chroma` ou `Palette`, ou do
`<id>.gd` de um módulo que a estende: um mod que traz `two_tone.gd` com
`extends Chroma` pinta do jeito dele, reescrevendo `paint`. Um mod troca a chroma
do jogo trazendo uma de mesmo id. Qualquer outra chave da chroma é do jogo, como
uma cor de contorno que só ele lê.

Por ora a lib pinta na CPU, uma vez por sprite e cores, e guarda o resultado. A
API já serve para um shader, que pode vir quando um jogo recolorir a cada quadro.

---

## ⚠️ Nomes reservados

GDScript **não tem namespace**. Todo `class_name` da lib ocupa o registro
global do projeto inteiro. Um jogo que declarar qualquer um destes 59 nomes
colide com a engine:

```
AddOperator             AncestorValidator  Asset              AssetManager
Bus                     Chroma             ClassRefValidator  Cmd
Codex                   D5                 D5Hub              D5Manager
Def                     DefManager         Directories        DirectoriesParser
DivideOperator          Flow               Game               JsonLoader
KindDef                 Loader             MediaHub           Menu
ModuleInfo              ModuleManager      MultiplyOperator   Overlay
Palette                 Parser             ParserManager      PartsValidator
PathManager             Record             ResourceManager    RuleHub
RulesParser             SaveHub            SceneFlow          SceneLoader
ScriptBindingValidator  ScriptLoader       SeedRng            ShaderLoader
SoundLoader             SubtractOperator   TextureLoader      Thing
ThingAssembler          ThingCatalog       ThingData          ThingHub
ThingOperator           ThingPart          ThingType          ThingVariant
Validator               ValidatorManager   World
```

Três nomes já foram cedidos aos jogos de propósito, porque eram genéricos
demais para uma lib compartilhada:

| Era | Virou | Motivo |
|---|---|---|
| `Manager` | `D5Manager` | "manager" é substantivo central de jogos de gestão |
| `Selection` | `Record` | libera escalação / seleção. Passou por `Slate` na v0.1.0; renomeado na v0.2.0 porque "Slate" era evocativo mas não descrevia o padrão — a classe é um Memento tipado, e "snapshot" é a palavra que a própria classe usa pra se descrever |
| `Rules` | `Codex` | libera regras de liga |

---

## Invariantes de layout

A lib se auto-localiza a partir de dois arquivos. Se você mover **estes**,
ajuste o número de `get_base_dir()`:

| Arquivo | Posição esperada | Deriva |
|---|---|---|
| `globals/drive/drive.gd` | `<raiz>/globals/drive/` | raiz da engine |
| `plugin/d5star_plugin.gd` | `<raiz>/plugin/` | raiz do addon |

Uma exceção: `game/game.tscn` referencia seu script por `uid://` (autoritativo,
viaja com o addon) e, como fallback textual, pelo caminho canônico
`res://addons/d5star/`. Cenas não computam caminhos — por isso a lib precisa
ficar exatamente em `res://addons/d5star/`, que é também o que o `plugin.cfg`
exige.

Todo o resto dos caminhos internos vem do `engine.json`.
