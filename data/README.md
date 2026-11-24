# Данные

Видео в репозиторий не коммитятся: папки `data/raw/` и `data/processed/` в `.gitignore`.

## Источник

Датасет кейса выдают организаторы Solveathon (`seriq-dataset.zip`, ~1,2 ГБ, 491 видео). Это публичный датасет:
*An upper limb stroke rehabilitation exercise video dataset*, Mendeley Data, DOI [10.17632/49h9dcwx5v.1](https://data.mendeley.com/datasets/49h9dcwx5v/1).

## Структура архива

```
An upper limb stroke rehabilitation exercise video/Exercise/
  <N_Exercise>/<Complete|Incomplete>/<Train|Test>/VV_EE_C_NN.mp4
```

- `VV` — ID добровольца
- `EE` — номер упражнения (02 = разгибание локтя, наша задача)
- `C` — 1 = complete, 0 = incomplete
- `NN` — номер повтора

Отдельных файлов разметки нет: класс берётся из папки и имени файла.

## E02 (Extending the Elbow)

| Выборка | Добровольцы | Complete | Incomplete |
|---|---|---|---|
| Train | 01–05 | 50 | 57 |
| Test | 08 | 10 | 10 |

## Как подключить

Распаковать только E02 в `data/raw/`:

```bash
unzip -q path/to/seriq-dataset.zip "*/2_Extending the Elbow/*" -d data/raw/
```
