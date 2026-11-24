# Data

Videos are **not** part of this repository. `data/raw/` and `data/processed/` are listed in `.gitignore`.

## Source

The case dataset is distributed by the Solveathon organizers as `seriq-dataset.zip` (~1.2 GB, 491 videos). It is the public dataset *An upper limb stroke rehabilitation exercise video dataset*, Mendeley Data, DOI [10.17632/49h9dcwx5v.1](https://data.mendeley.com/datasets/49h9dcwx5v/1), license CC BY 4.0.

## Archive structure

```text
An upper limb stroke rehabilitation exercise video/Exercise/
  <N_ExerciseName>/<Complete|Incomplete>/<Train|Test>/VV_EE_CC_NN.mp4
```

- `VV` — volunteer ID
- `EE` — exercise number (`02` = elbow extension, our task)
- `CC` — class flag, `01` complete, `00` incomplete
- `NN` — repetition number

There are no separate annotation files. **The class label is taken from the folder name**, because the file names of volunteer 04 do not match their folder. Details: [docs/dataset-analysis.md](../docs/dataset-analysis.md).

## E02 (Extending the Elbow)

| Split | Volunteers | Complete | Incomplete |
|---|---|---|---|
| Train | 01–05 | 50 | 57 |
| Test | 08 | 10 | 10 |

## Setup

Extract only E02 into `data/raw/` (about 274 MB). Run from the repository root:

```bash
unzip -q path/to/seriq-dataset.zip "*/2_Extending the Elbow/*" -d data/raw/
```

Expected result: 127 `.mp4` files under `data/raw/An upper limb stroke rehabilitation exercise video/Exercise/2_Extending the Elbow/`.
