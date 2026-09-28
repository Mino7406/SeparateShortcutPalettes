<div align="center">

# Separate Shortcut Palettes (Keyboard & Gamepad)

몬스터 헌터 와일즈에서 키보드와 게임패드가 하나의 숏컷 팔레트를 같이 쓰는 대신, 각각 따로 저장하게 만듭니다. [REFramework](https://github.com/praydog/REFramework) 기반 lua 스크립트입니다.

[![Platform](https://img.shields.io/badge/platform-Windows-0078D6?style=flat-square&logo=windows&logoColor=white)]()
[![REFramework](https://img.shields.io/badge/REFramework-lua-5865F2?style=flat-square)](https://github.com/praydog/REFramework)
[![Nexus Mods](https://img.shields.io/badge/Nexus%20Mods-download-D98F40?style=flat-square)](https://www.nexusmods.com/monsterhunterwilds/mods/4991)
[![License: MIT](https://img.shields.io/badge/license-MIT-4c1?style=flat-square)](LICENSE)
![language](https://img.shields.io/badge/docs-한국어-blue?style=flat-square)

*[Read in English](README.md) · [Nexus Mods 페이지](https://www.nexusmods.com/monsterhunterwilds/mods/4991)*

</div>

## 문제

와일즈는 숏컷 팔레트를 **한 세트만** 가지고 있고, 두 입력 방식이 그것을 함께 읽고 씁니다. 패드로 팔레트를 바꾸면 키보드 팔레트도 같이 바뀌고, 반대도 마찬가지입니다. 두 장치를 오가며 플레이하면 자신이 정리해 둔 배치를 계속 스스로 망가뜨리게 됩니다.

---

## 하는 일

패드용과 키보드용 사본을 각각 하나씩 보관하다가, 지금 쓰는 장치가 바뀌면 그 장치의 사본을 게임에 넣어줍니다. 패드 버튼을 누르면 패드 팔레트가, 키보드 키를 누르면 키보드 팔레트가 됩니다. 한쪽에서 바꾼 내용은 다른 쪽에 영향을 주지 않습니다.

팔레트에 들어 있는 것은 전부 분리됩니다. 아이템, 팔레트 이름, 아이콘까지 모두요. 캐릭터마다 자기만의 두 세트를 가집니다.

---

## 설치

[넥서스 모드](https://www.nexusmods.com/monsterhunterwilds/mods/4991)나 [GitHub 릴리즈](../../releases)에서 받아 몬스터 헌터 와일즈 폴더에 풀어서 아래처럼 되게 합니다.

```
MonsterHunterWilds/
└─ reframework/
   └─ autorun/
      └─ SeparateShortcutPalettes.lua
```

> [!NOTE]
> [REFramework](https://github.com/praydog/REFramework)가 필요합니다. 따로 실행하거나 설치할 것은 없고, 게임을 켜면 파일이 자동으로 로드됩니다.

---

## 게임 내 사용 방법

게임을 켜고 캐릭터를 불러온 뒤 **Insert**를 눌러 REFramework 메뉴를 열고, **Script Generated UI → Separate Shortcut Palettes**를 엽니다. 상태 표시줄이 초록색으로 `Active: Gamepad palettes`라고 나오면 정상입니다.

처음 실행하면 두 장치 모두 지금 팔레트로 시작합니다. 한 장치로 팔레트를 바꾸고 다른 장치의 버튼을 누르면, 그 장치는 바꾸기 전 팔레트로 돌아와 있습니다.

---

## 동작 방식

게임은 메모리의 세이브 데이터 객체에 팔레트를 보관하고 있습니다.

```
save._Item._ShortcutPallet
 ├─ _ShortcutData[8]        팔레트 8개
 │   ├─ Name, _Symbol       이름과 아이콘
 │   └─ _Items[12]          칸마다 { Type, Value }
 └─ CurrentIndex
```

**`lua/SeparateShortcutPalettes.lua`**는 이 객체를 읽어서 패드 사본과 키보드 사본을 `reframework/data/SeparateShortcutPalettes.json`에 보관하고, 마지막으로 쓴 장치가 무엇인지 지켜봅니다. 장치가 바뀌면 지금 게임에 있는 팔레트를 방금 떠난 장치의 사본에 저장하고, 새 장치의 사본을 게임에 씁니다. 게임 안에서 편집한 내용은 1초 안에 감지해서 지금 장치의 사본에 저장합니다.

**장치 감지**는 "눌려 있는가"가 아니라 "새로 눌렀는가"를 봅니다. 패드는 엔진의 통합 `via.hid.GamePad` 장치의 버튼 상태로, 키보드는 `reframework:is_key_down`으로 읽습니다. 그래서 버튼 하나가 눌린 채 고장 나거나 키가 계속 눌려 있어도 한쪽에 고정되지 않습니다. Shift/Ctrl/Alt, Insert, Home, End, Delete, PageUp/Down 키와 Alt를 누른 채 누르는 키는 무시하므로 오버레이 단축키(REFramework, ReShade, Steam)가 잡히지 않게 했고, 마우스는 아예 쓰지 않습니다. 메뉴에서 클릭하는 게 키보드 입력으로 오인되면 안 되기 때문입니다.

<details>
<summary>🧩 <b>알아두면 좋은 점</b></summary>

**아무 값이나 막 쓰지 않습니다.** 저장된 사본은 게임에 첫 값을 쓰기 전에 전부 검증합니다. 쓰는 도중 게임이 거부하면 팔레트를 원래대로 되돌리고 메뉴에 오류를 표시합니다.

**빈 세이브가 사본을 덮어쓰지 않습니다.** 로딩 중인 세이브는 팔레트가 전부 빈 것처럼 보이기 때문에, 그 상태는 저장하지 않습니다. 캐릭터가 잠시 안정적으로 보일 때까지 기다린 뒤에야 건드립니다.

**lua 파일 입출력은 `reframework/data` 안으로 제한됩니다.** 그래서 데이터 파일 이름에 경로가 없고, 그 폴더에 만들어집니다.

**남는 파일은 하나뿐입니다.** `reframework/data/SeparateShortcutPalettes.json`에 설정과 캐릭터별 두 사본이 들어 있습니다. 지우면 지금 팔레트에서 다시 시작합니다.

</details>

---

## 설정

REFramework 메뉴(Insert)의 **Separate Shortcut Palettes**에 있습니다.

- **Enabled** — 모드를 켜고 끕니다. 끄면 팔레트가 지금 상태로 멈춥니다.
- **Also separate the selected palette number (experimental)** — 끄면 선택된 팔레트 번호(1, 2, 3…)는 공유하고 내용만 분리합니다. 필요하지 않으면 끄세요. 자세한 건 NOTES를 참고하세요.
- **Gamepad palettes / Keyboard palettes** — 수동으로 전환합니다. 보통은 자동으로 됩니다.
- **Advanced** — 마지막으로 감지된 입력, 사용 중인 패드 API, 마지막 오류, 그리고 *Copy current palettes to both devices*(실행 전 확인창이 뜹니다).

> [!TIP]
> 패드를 써도 전환이 안 되면 **Advanced**를 열고 패드 버튼을 몇 개 눌러 **Last input**을 보세요. *Gamepad*로 나와야 합니다. 계속 안 바뀌면 컨트롤러 모델과 Steam Input 사용 여부를 적어서 이슈를 남겨주세요.

---

## 한계

- 듀얼센스에서만 테스트했습니다. 감지는 드라이버가 아니라 엔진의 게임패드 인터페이스를 거치니 다른 컨트롤러도 될 것으로 보이지만, 확인하지는 못했습니다.
- 키보드에서 패드로 돌아올 때는 패드 **버튼**을 눌러야 합니다. 스틱만 움직이거나 트리거만 당겨서는 전환되지 않을 수 있습니다.
- 팔레트 편집 화면을 연 채 장치를 바꾸면 그 순간 팔레트가 바뀝니다. 화면의 목록은 다시 열어야 갱신될 수 있습니다.
- 키보드 감지는 전역 키 상태를 쓰기 때문에, 게임 창이 비활성일 때 새로 누른 키도 키보드 팔레트로 전환시킬 수 있습니다.
- 96칸을 **전부** 비우면 모드가 멈춥니다(로딩 안 된 세이브처럼 보이기 때문). 아이템을 하나 다시 넣으면 재개됩니다.
- 캐릭터를 불러올 때마다 모드가 보관 중인 사본을 게임에 적용합니다. 예전 세이브를 복원하거나 다른 PC에서 동기화하면 모드의 사본이 우선 적용됩니다. 지금 보이는 팔레트를 유지하려면 *Copy current palettes to both devices*를 쓰세요.
- 게임 업데이트로 세이브 필드 이름이 바뀌면 메뉴에 *Shortcut palettes not found*가 뜨고 모드는 아무것도 하지 않습니다.

---

## 삭제

`reframework/autorun/SeparateShortcutPalettes.lua`를 지웁니다(원하면 `reframework/data/SeparateShortcutPalettes.json`도). 팔레트는 그 시점 그대로, 즉 마지막으로 쓰던 장치의 세트로 남습니다. 다른 장치의 세트를 남기고 싶으면 지우기 전에 메뉴에서 그 장치로 전환해 두세요.

---

## 릴리즈 만들기

```powershell
./build.ps1
```

lua와 텍스트 README가 들어 있는 `out/SeparateShortcutPalettes.zip`을 만듭니다. 컴파일할 것은 없습니다.

## 라이선스

[MIT](LICENSE)
