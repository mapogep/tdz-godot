# Генерация игровых 2D/3D-ассетов на сервере SwarmUI — памятка для агента

Проверено 30.09.2026. Всё ниже реально работает; то, чего нет в списке, — не установлено.

## 1. Сервер и правила

* SwarmUI: `http://93.170.220.177:7801` (в локальной сети — `http://192.168.0.116:7801`).
  ComfyUI-бэкенд — через прокси `…:7801/ComfyBackendDirect/…` (свой порт ComfyUI меняется при каждом перезапуске, не используй его).
* GPU RTX 3060 12 GB. **Строго один запрос за раз**, никаких параллельных задач.
* Канал до сервера медленный (~3 Мбит/с) и иногда рвётся: опрос результата делай с повтором при сетевой ошибке, задание на сервере от этого не прерывается.
* Ничего на сервере не устанавливай и не чини сам. Если нужна установка — напиши текст задания пользователю, он передаст его Claude Code на сервере.
* Платные партнёрские ноды (Tripo*, Meshy*, Rodin*, Tencent*, Bria*, Recraft*) не использовать.

## 2. Что доступно

| Задача | Что есть |
|---|---|
| Картинки | `sd_xl_base_1.0.safetensors`, `pixel-xl-sdxl-base.safetensors`; LoRA: `pixel-art-xl-v1.1`, `16-bit-pixel-backgrounds-v2`, `lucasarts_style_sdxl_v1.0` (триггер `lcas artstyle`), `pixel-art-sprite-sheet-space-candy-media`, `sdxl2d-pixel-toolkit-2d` |
| Удаление фона | параметр SwarmUI `removebackground: true` и нода `SwarmRemBg` — работают |
| **3D с текстурой (основной)** | ComfyUI-Hunyuan3DWrapper: форма `hunyuan3d-dit-v2-mini-turbo-fp16.safetensors`, раскраска `hunyuan3d-paint-v2-0-turbo`, `hunyuan3d-delight-v2-0` → GLB с UV и PBR-текстурой 2048² |
| 3D без текстуры (запасной) | TripoSR (`TripoSR_model.ckpt` → `SaveGLB`), цвет в вершинах, грубее |
| **Нет** | Hunyuan3D-2mv (многоракурсный), TRELLIS, ComfyUI-3D-Pack (отключены/не влезают в 12 GB) |

## 3. Пайплайн «картинка → 3D-модель»

### Шаг 1. Референс в SDXL (`POST /API/GetNewSession`, затем `POST /API/GenerateText2Image`)

```json
{"session_id": "...", "images": 4, "model": "sd_xl_base_1.0.safetensors",
 "width": 1024, "height": 1024, "steps": 32, "cfgscale": 7, "seed": 7501,
 "sampler": "dpmpp_2m", "scheduler": "karras", "prompt": "...", "negativeprompt": "..."}
```
Ответ: `images` — пути `View/local/raw/...png` (скачивать `GET /<путь>`, URL-кодировать пробелы) или data-URL.

* Всегда 4 варианта одним запросом и выбирай глазами лучший. Квадрат **1024×1024** (3D-граф требует квадрат).
* Шаблон для предметов:
  `3d model render of a single <ОБЪЕКТ>, stylized military game asset, <материалы/цвет>, three-quarter view from the front left and slightly above, whole object in frame with margin, centered, isolated on a plain flat light grey background, soft even studio lighting, clean readable shapes, highly detailed`
* Шаблон для персонажей: `full body 3d character model render of <КТО>, standing in a neutral A-pose, orthographic front view, facing the camera, (arms held away from the body:1.3), <одежда>, whole body in frame from head to shoes with margin, centered, single character, plain flat light grey background, soft even studio lighting, stylized game character, highly detailed`
* Негатив: `text, letters, numbers, watermark, logo, multiple objects, cropped, cut off, blurry, lowres, frame, border, dark background, dramatic lighting, floor, ground shadow` + то, что SDXL упорно дорисовывает (для персонажа в кроссовках — `boots`, для башни — `tank, tracks, wheels`).
* Важные детали усиливай весом: `(dirty white sneakers:1.5)`, `(tight black leggings:1.4)`. Без веса SDXL подменяет (ботинки вместо кроссовок, целый танк вместо башни).
* Ствол/длинная деталь не должна смотреть в камеру — проси `pointing to the left side, whole barrel visible in profile`.
* SDXL **не умеет** «ряд одинаковых предметов» (бочки в ряд), «лист с ракурсами» (виды не совпадают), «зелёный фон». Ряды собирай из одного 3D-модуля копиями.

### Шаг 2. 3D через Hunyuan3D (ComfyUI API)

1. `POST /ComfyBackendDirect/upload/image` (multipart, поле `image`, `overwrite=true`) → `{"name": ...}`. Подавай **оригинал из SDXL** — фон удаляется внутри графа.
2. `POST /ComfyBackendDirect/prompt` с `{"prompt": <граф>, "client_id": "<uuid>"}` → `prompt_id`.
3. Опрашивай `GET /ComfyBackendDirect/history/<prompt_id>` каждые 5 с, пока id не появится. Результат: `outputs["90"]["3d"][0]` = `{filename, subfolder: "3D", type: "output"}`.
4. `GET /ComfyBackendDirect/view?filename=<…>&subfolder=3D&type=output` → .glb.

Граф (подставь имя картинки в узел `1`; настраиваемые параметры — ниже):

```json
{
 "1": {"class_type": "LoadImage", "inputs": {"image": "<uploaded name>"}},
 "2": {"class_type": "SwarmRemBg", "inputs": {"images": ["1", 0]}},
 "3": {"class_type": "InvertMask", "inputs": {"mask": ["2", 1]}},
 "10": {"class_type": "Hy3DModelLoader", "inputs": {"model": "hunyuan3d-dit-v2-mini-turbo-fp16.safetensors", "attention_mode": "sdpa", "cublas_ops": false}},
 "11": {"class_type": "Hy3DGenerateMesh", "inputs": {"pipeline": ["10", 0], "image": ["1", 0], "mask": ["3", 0], "guidance_scale": 5.0, "steps": 5, "seed": 42, "scheduler": "ConsistencyFlowMatchEulerDiscreteScheduler", "force_offload": true}},
 "12": {"class_type": "Hy3DVAEDecode", "inputs": {"vae": ["10", 1], "latents": ["11", 0], "box_v": 1.01, "octree_resolution": 384, "num_chunks": 8000, "mc_level": 0.0, "mc_algo": "mc", "enable_flash_vdm": true, "force_offload": true}},
 "13": {"class_type": "Hy3DPostprocessMesh", "inputs": {"trimesh": ["12", 0], "remove_floaters": true, "remove_degenerate_faces": true, "reduce_faces": true, "max_facenum": 5000, "smooth_normals": false}},
 "20": {"class_type": "SolidMask", "inputs": {"value": 0.8, "width": 1024, "height": 1024}},
 "21": {"class_type": "MaskToImage", "inputs": {"mask": ["20", 0]}},
 "22": {"class_type": "ImageScale", "inputs": {"image": ["1", 0], "upscale_method": "lanczos", "width": 1024, "height": 1024, "crop": "center"}},
 "23": {"class_type": "ImageCompositeMasked", "inputs": {"destination": ["21", 0], "source": ["22", 0], "x": 0, "y": 0, "resize_source": false, "mask": ["3", 0]}},
 "24": {"class_type": "DownloadAndLoadHy3DDelightModel", "inputs": {"model": "hunyuan3d-delight-v2-0"}},
 "25": {"class_type": "Hy3DDelightImage", "inputs": {"delight_pipe": ["24", 0], "image": ["23", 0], "steps": 50, "width": 512, "height": 512, "cfg_image": 1.0, "seed": 42}},
 "30": {"class_type": "Hy3DMeshUVWrap", "inputs": {"trimesh": ["13", 0]}},
 "31": {"class_type": "Hy3DCameraConfig", "inputs": {"camera_azimuths": "0, 90, 180, 270, 0, 180", "camera_elevations": "0, 0, 0, 0, 90, -90", "view_weights": "1, 0.3, 0.7, 0.3, 0.3, 0.05", "camera_distance": 1.45, "ortho_scale": 1.2}},
 "32": {"class_type": "Hy3DRenderMultiView", "inputs": {"trimesh": ["30", 0], "render_size": 1024, "texture_size": 2048, "camera_config": ["31", 0], "normal_space": "world"}},
 "40": {"class_type": "DownloadAndLoadHy3DPaintModel", "inputs": {"model": "hunyuan3d-paint-v2-0-turbo"}},
 "41": {"class_type": "Hy3DSampleMultiView", "inputs": {"pipeline": ["40", 0], "ref_image": ["25", 0], "normal_maps": ["32", 0], "position_maps": ["32", 1], "view_size": 512, "steps": 10, "seed": 42, "camera_config": ["31", 0], "denoise_strength": 1.0}},
 "42": {"class_type": "ImageScale", "inputs": {"image": ["41", 0], "upscale_method": "lanczos", "width": 2048, "height": 2048, "crop": "disabled"}},
 "50": {"class_type": "Hy3DBakeFromMultiview", "inputs": {"images": ["42", 0], "renderer": ["32", 2], "camera_config": ["31", 0]}},
 "51": {"class_type": "Hy3DMeshVerticeInpaintTexture", "inputs": {"texture": ["50", 0], "mask": ["50", 1], "renderer": ["50", 2]}},
 "52": {"class_type": "CV2InpaintTexture", "inputs": {"texture": ["51", 0], "mask": ["51", 1], "inpaint_radius": 3, "inpaint_method": "ns"}},
 "53": {"class_type": "Hy3DApplyTexture", "inputs": {"texture": ["52", 0], "renderer": ["51", 2]}},
 "90": {"class_type": "Hy3DExportMesh", "inputs": {"trimesh": ["53", 0], "filename_prefix": "3D/<имя>", "file_format": "glb", "save_file": true}}
}
```

Время: 45–120 с на модель, пик VRAM ~7 GB. Только форма без текстуры: убери узлы 20–53 и подай `["13", 0]` в узел 90.

### Настройки (проверено сравнением)

| Параметр | Техника, предметы | Персонажи (важно лицо) |
|---|---|---|
| `13.max_facenum` | турели 5000, блоки/бочки 1500 | 6000 (рядовой враг), 20–40k только для героя |
| `31.view_weights` | `1, 0.3, 0.7, 0.3, 0.3, 0.05` | то же |
| `41.view_size` и `25.width/height` | **512** (768 смывает полосы, ржавчину, рисунок) | **768** (лицо заметно чётче) |
| delight (узлы 24–25) | оставлять (без него хуже) | оставлять |

* `max_facenum` уменьшает сетку **до** развёртки и запекания — текстура ложится прямо на лёгкую модель; 6000 выглядит почти как 40000.
* Один и тот же seed + та же картинка → та же сетка. Несколько раскрасок одной сетки = несколько веток 20–90 в одном графе (свои номера узлов, общий `30`).

### Шаг 3. Проверка результата

GLB должен содержать `TEXCOORD_0`, 1 материал и 1 встроенную PNG 2048². Отрендерь 4 ракурса (перед/бок/спина/сверху) и посмотри глазами: спину модель додумывает, верх (шляпы, крыши) раскрашивается хуже всего.

## 4. Приёмы

* **Цветовые варианты одного врага** — не перерисовывай референс (раскраска выдумает спину по-другому). Перекрашивай готовую текстуру: для каждого текселя найти треугольник → высоту на теле; часть = полоса высоты + цвет (тёмное в зоне ног = штаны и т.п.). Сетка и UV остаются общими → в игре одна модель, разные текстуры.
* **Заборы и ряды** — одна 3D-модель модуля + несколько узлов GLB, ссылающихся на ту же сетку (смещение вдоль длинной оси, лёгкий случайный поворот). Весит как один модуль.
* **Турели в игре** должны вращаться: башня и основание получаются одной сеткой — для поворота её нужно разрезать по высоте на две части с осью вращения.
* Для толпы: текстуры можно ужать до 1024 без видимой разницы.
* Если нужен свой вырез фона локально: плавный градиент фона по краям + OpenCV GrabCut (белая одежда на светло-сером фоне цветом не отделяется). Но обычно достаточно `SwarmRemBg` в графе.

## 5. Известные недостатки

* Верх объекта (шляпа, крыша) — пятнистая текстура; спина — додумана.
* Лица иногда зеленоватые, кровь бывает перенасыщена.
* Цвета по сравнению с референсом чуть желтее/бледнее.
