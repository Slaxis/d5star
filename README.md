# D5Star

Biblioteca data-driven de criação de jogos em Godot 4.7. Tudo que o jogo
define vive em JSON; o código da engine é genérico e nunca sabe o nome de
nada específico de um jogo.

Consumida como **git submodule** em `res://addons/d5star/`.

---

## Instalação

```bash
git submodule add https://github.com/Slaxis/d5star.git addons/d5star
git submodule update --init --recursive
```

Abra o projeto no Godot e habilite **D5Star** em `Project Settings > Plugins`.
O plugin registra os oito autoloads na ordem correta — o jogo nunca escreve
essas linhas no `project.godot` à mão:

```
Air · Log · Drive · God · The · I18n · SaveManager · Audio
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

---

## ⚠️ Nomes reservados

GDScript **não tem namespace**. Todo `class_name` da lib ocupa o registro
global do projeto inteiro. Um jogo que declarar qualquer um destes 54 nomes
colide com a engine:

```
AncestorValidator   Asset          AssetManager      Bus
Card                CardView       ClassRefValidator Cmd
Codex               D5Manager      Deck              Def
DefManager          Directories    DirectoriesParser Flow
Game                Hand           HandView          JsonLoader
Loader              MediaHub       Menu              ModuleInfo
ModuleManager       Overlay        Parser            ParserManager
PartsValidator      PathManager    ResourceManager   RuleHub
RulesParser         SceneFlow      SceneLoader       ScriptBindingValidator
ScriptLoader        SeedRng        ShaderLoader      Slate
SoundLoader         TextureLoader  Thing             ThingAssembler
ThingCatalog        ThingData      ThingHub          ThingPart
ThingStateMachine   ThingType      ThingVariant      Validator
ValidatorManager    World
```

Três nomes já foram cedidos aos jogos de propósito, porque eram genéricos
demais para uma lib compartilhada:

| Era | Virou | Motivo |
|---|---|---|
| `Manager` | `D5Manager` | "manager" é substantivo central de jogos de gestão |
| `Selection` | `Slate` | libera escalação / seleção |
| `Rules` | `Codex` | libera regras de liga |

---

## Invariantes de layout

A lib se auto-localiza a partir de dois arquivos. Se você mover **estes**,
ajuste o número de `get_base_dir()`:

| Arquivo | Posição esperada | Deriva |
|---|---|---|
| `globals/drive/drive.gd` | `<raiz>/globals/drive/` | raiz da engine |
| `d5star_plugin.gd` | `<raiz>/` | raiz do addon |

Todo o resto dos caminhos internos vem do `engine.json`.
