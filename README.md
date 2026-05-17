# ArborSim
## Xiuping's Generated Model Navigation

This fork includes my customized Sue/T. rex-inspired models generated using ArborSim. I modeled both the leg and neck of a simplified Sue/T. rex-inspired structure and compared two branching configurations for each model: one branch point and two branch points. These models were mainly created to explore how different branch point settings affect the generated conventional and proposed OpenSim models.

The simulation results are not ideal. Since the simulation scripts are highly dependent on the original ArborSim toy model setup, they do not transfer perfectly to the customized leg and neck models.

### Model Folders

- `Models/Sue_Inspired_Models/`
  - Contains the generated Sue-inspired leg and neck OpenSim models.
  - Includes both conventional and proposed branching model outputs when available.

- `scripts/`
  - Contains MATLAB scripts used to define body geometry, joints, MTU paths, ligament branches, wrapping surfaces, and simulation setup.

- `Simulations/`
  - Contains simulation files and outputs used to test model behavior.

### Current Modeling Focus

The current models focus on simplified Sue/T. rex-inspired musculoskeletal structures, especially:

- branched muscle-tendon architecture
- branch count comparison
- passive ligament behavior
- joint coordinate constraints
- knee wrapping surface design
- conventional vs. proposed ArborSim model generation

---

## Original ArborSim Description
ArborSim (Articulated, Branching, OpenSim Routing for Constructing Models of Multi-jointed Appendages with Complex Muscle-Tendon Architecture) is a dedicated software framework for musculoskeletal modeling. Its primary role is to assist biomechanics researchers in efficiently constructing models of articulated appendages from CT scans and dissection data, with the data organized into multiple Comma-Separated Values (CSV) files.

ArborSim is designed to integrate seamlessly with the [API of OpenSim](https://github.com/opensim-org/opensim-core), a widely recognized open-source software for modeling, simulating, and analyzing musculoskeletal systems. This integration is intended to streamline model development and faciliate sharing within the research community.

One of the distinctive features of ArborSim is its novel approach to modeling complex muscle-tendon architectures, particularly in cases of branching. Traditionally, musculoskeletal modeling represents these architectures as distinct, separate, and independent compartments. In contrast, ArborSim introduces a method where branched muscle-tendon architectures are depicted as assemblies of individual muscular and tendinous elements that are interconnected, providing a more nuanced representation of the interactions within branched muscle-tendon architectures.

ArborSim offers versatility in modeling techniques. It allows users to choose between the traditional (parallel) method of modeling branching muscle-tendon architectures and the novel (explicitly branched) approach.

For more information about ArborSim, including its approach to modeling branching muscle-tendon architectures, please refer to our accompanying paper: [https://www.biorxiv.org/content/10.1101/2024.01.13.575515v1](https://www.biorxiv.org/content/10.1101/2024.01.13.575515v1)

## Installation
Follow these steps to install ArborSim:

1. **Download and Install OpenSim**:
   - Visit the OpenSim official website: [OpenSim Downloads](https://opensim.stanford.edu/)
   - Follow the installation instructions specific to your operating system.

2. **Download and Install MATLAB**:
   - Ensure MATLAB is installed on your system. Visit [MATLAB Downloads](https://www.mathworks.com/downloads/) for instructions.

3. **Set up OpenSim Library in MATLAB**:
   - After installing OpenSim and MATLAB, configure MATLAB to access OpenSim's functionality by following these instructions: [Scripting with MATLAB](https://simtk-confluence.stanford.edu:8443/display/OpenSim/Scripting+with+Matlab).

4. **Clone the ArborSim Repository**:
   - Clone the ArborSim repository to your local machine using the following command:
     ```
     git clone https://github.com/EMBiRLab/ArborSim.git
     ```

## Repository Structure
The ArborSim repository includes the following directories:

- **`Models`**: Hosts source data for building models and constructed model files. It comes preloaded with an introductory example for new users and toy musculoskeletal models involved in the accompanying paper. For comprehensive details on the directory structure and data format guidelines, refer to the [README](./Models/README.md) within this directory.
- **`Scripts`**: Contains MATLAB scripts for constructing musculoskeletal models from the data in the `Models` directory. A [README](./Scripts/README.md) providing a description of this directory's contents is also available.
- **`Simulations`**: Contains MATLAB scripts and results for simulating the toy musculoskeletal models used for the comparisons and sensitivity analyses in the accompanying paper.

## Quick Start
To get started with ArborSim:

1. Navigate to the `Scripts` folder.
2. Run the `create_my_first_model.m` script to build your first model.
3. Edit the data for model construction as necessary to explore the tool's capabilities.
4. Load the model into OpenSim and create your own scripts for simulating the model according to your research objectives.

## Compatibility Information
To aid in setting up a suitable environment for ArborSim, please note that ArborSim was developed and tested with the following specific versions of the software:

- **MATLAB**: MATLAB R2023b
- **OpenSim**: OpenSim 4.4

We recommend these versions as a reference point for optimal compatibility and performance. ArborSim can operate with different versions, but we cannot make predictions regarding the variations in performance. We encourage users to report any compatibility issues they encounter to help us improve ArborSim.

## Contributing
Contributions to ArborSim are welcome! Please refer to [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on how to contribute.

## Support and Contact
For support, questions, or feedback, please open an issue on the [GitHub Issue Tracker](https://github.com/xunfu/ArborSim/issues) or contact the authors directly.

## License
ArborSim is licensed under the Apache License, Version 2.0. For more information, see the [LICENSE](./LICENSE) file.

## Authors
Xun Fu (xunfu@umich.edu)
Jack Withers (jawither@umich.edu)
Juri Miyamae (jmiyamae@umich.edu)
Talia Y. Moore (taliaym@umich.edu)
