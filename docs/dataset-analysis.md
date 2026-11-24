# Dataset Analysis

Status: **completed for metadata** (file structure, labels, subject IDs, video properties). Pose-level analysis (landmark quality, elbow-angle curves) has not been done yet.

Date of analysis: 2026-11-24.

## Source

| Field | Value |
|---|---|
| Title | *An upper limb stroke rehabilitation exercise video dataset* |
| Authors | Binoy Nair, S Nandana, M Thenmozhi Dharshini, Vismaya Viswanathan (Amrita Vishwa Vidyapeetham) |
| Published | 26 February 2026, Mendeley Data, version 1 |
| DOI | [10.17632/49h9dcwx5v.1](https://data.mendeley.com/datasets/49h9dcwx5v/1) |
| License | CC BY 4.0 |
| Provided to teams as | `seriq-dataset.zip` (~1.2 GB) on the [Solveathon cases page](https://solveathon.shakarim.edu.kz/en/problems/) |

According to the dataset page:

- Each video contains **one exercise cycle**, from start to end.
- Videos were reviewed manually and labelled `complete` (exercise performed successfully) or `incomplete` (difficulty or failure in execution).
- Videos were recorded with a mobile phone camera and a webcam.
- Exercises follow the *Self-rehabilitation booklet for Hemiplegic patients* (Bonnyaud, Jinwala, Roche, 2015).
- The page does not state the number of volunteers or whether they are patients or healthy people.

## Archive structure

```text
An upper limb stroke rehabilitation exercise video/Exercise/
  <N_ExerciseName>/<Complete|Incomplete>/<Train|Test>/VV_EE_CC_NN.mp4
```

| Part | Meaning |
|---|---|
| `VV` | Volunteer (subject) ID |
| `EE` | Exercise number (`02` = elbow extension) |
| `CC` | Class flag: `01` complete, `00` incomplete (see the label issue below) |
| `NN` | Repetition number |

The archive contains only `.mp4` files. There are no annotation files, CSV tables or landmark data.

## All exercises

| Exercise | Train complete | Train incomplete | Test complete | Test incomplete | Train volunteers | Test volunteer |
|---|---|---|---|---|---|---|
| 1 Lifting an Object | 52 | 51 | 10 | 10 | 01–05 | 07 |
| **2 Extending the Elbow (E02)** | **50** | **57** | **10** | **10** | **01–05** | **08** |
| 3 Lifting the Wrist | 50 | 51 | 10 | 10 | 02–06 | 10 |
| 4 Opening the Hand | 50 | 50 | 10 | 10 | 01–06 | 09 |

Total: 491 videos. The organizers' Train/Test split is already subject-independent: each exercise has a single test volunteer who does not appear in any training set.

## E02 — Extending the Elbow

127 videos, 274 MB after extraction.

| Split | Volunteer | Complete | Incomplete | Resolution | Orientation | FPS | Duration, s |
|---|---|---|---|---|---|---|---|
| Train | 01 | 9 | 12 | 1620×2880 | portrait | 30.0 | 9.5–12.6 |
| Train | 02 | 10 | 14 | 810×1800 | portrait | 29.6–30.0 | 9.2–14.8 |
| Train | 03 | 11 | 11 | 810×1800 | portrait | 28.9–30.0 | 4.9–13.2 |
| Train | 04 | 10 | 10 | 810×1440 | portrait | 25.1–27.6 | 9.5–14.8 |
| Train | 05 | 10 | 10 | 810×1440 | portrait | 23.8–27.0 | 10.5–13.0 |
| Test | 08 | 10 | 10 | 960×540 | landscape | 29.2–29.9 | 12.2–16.2 |
| **Total** | 6 | **60** | **67** | | | | 4.9–16.2 |

All videos are HEVC (H.265), with no rotation metadata. `ffprobe` reads the metadata of all 127 files without errors. Full frame decoding has not been checked yet.

## Findings

1. **Volunteer IDs are available** in file names, so a subject-wise split is possible without guessing.
2. **The test set is one person.** E02 test metrics will come from 20 videos of volunteer 08 only, so they will have high variance.
3. **Classes are close to balanced:** 50 vs 57 in train, 10 vs 10 in test.
4. **Domain shift between train and test.** Train videos are portrait phone recordings at 24–30 FPS. Test videos are landscape, 960×540, probably from a webcam. Features must not depend on resolution, orientation or frame rate.
5. **Duration does not separate the classes.** The median duration is 11.2 s for both complete and incomplete videos.
6. **One video is one cycle.** Training data are single-cycle clips, but a user's session may contain several repetitions. The application will need cycle segmentation before classification.

## Label issue: volunteer 04

The 10 files in `Complete/Train` for volunteer 04 are named `04_02_00_01 … 04_02_00_10`, so their class flag says `00` (incomplete). The 10 files in `Incomplete/Train` have the same names.

Checks performed:

- The two sets are **different videos**: MD5 hashes and durations differ.
- There are no byte-identical duplicates among the 127 E02 videos.
- This is the only mismatch in the whole archive.

Decision: **the class label is taken from the folder name**, not from the file name. A video is identified by its full relative path, because file names are not unique. This is an assumption: the folder is the more likely source of truth, but it has not been confirmed by the dataset authors.

## Not yet analysed

- Full pose estimation: in the training videos the shoulder is usually outside the frame (checked on vol01–05), so the AI core works from hand keypoints instead; see [architecture.md](architecture.md).
- Elbow-angle trajectories: analysed for the training set, plot in [figures/e02_angle_curves_train.png](figures/e02_angle_curves_train.png).
- Full frame decoding of every video.
