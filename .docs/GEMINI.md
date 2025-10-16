## Project Overview

This project is a comprehensive suite of tools for extracting, analyzing, and reporting on Jira data. It primarily uses PowerShell for scripting, with additional components in Power Query (M), and is designed to integrate with Power BI and Excel for data visualization and analysis. The project is structured around a large set of "endpoints," which are individual scripts that query specific Jira API endpoints.

The project is organized into several directories, with the core logic residing in the `.endpoints` and `.ps1` directories. The `.endpoints` directory contains a large number of PowerShell scripts, each corresponding to a specific Jira API call. These are categorized by Jira functionality (e.g., "Admin Organization," "Issue Search"). The `.ps1` directory contains more general-purpose and utility scripts.

Authentication is handled via two methods: Basic Authentication (with an API token) and OAuth2. The project includes detailed documentation on how to set up and use both authentication methods.

## Building and Running

This is not a compiled software project, so there is no formal "build" process. The project is run by executing the PowerShell scripts directly.

### Key Scripts:

*   `execute_all_get_endpoints.ps1`: This is the main script for executing all of the `GET` request endpoints. It dynamically finds all `.ps1` scripts in the `.endpoints` directory and executes them, creating CSV files with the retrieved data.
*   `list_endpoints_by_auth.ps1`: This script provides an overview of all the endpoints, categorized by the authentication method they use (Anonymous/Basic, OAuth2, or both).
*   `OAuth2_Authentication_Manager.ps1`: This script is used to manage the OAuth2 authentication process, including authorization, token refreshing, and testing.

### Running the project:

1.  **Prerequisites:**
    *   PowerShell 5.1+
    *   A Jira Cloud instance with API access.
    *   (Optional) Power BI Desktop and/or Excel for data analysis.

2.  **Configuration:**
    *   The project uses a combination of hardcoded credentials in the endpoint scripts and a more secure `.env` file approach (as mentioned in the `README.md`). For production use, it is highly recommended to use the `.env` file method.
    *   For OAuth2 authentication, follow the detailed instructions in `OAUTH2_SETUP_GUIDE.md` to create a Jira OAuth2 application and configure the `oauth2_config.json` file.

3.  **Execution:**
    *   Open a PowerShell terminal and navigate to the project's root directory.
    *   To run all `GET` endpoints, execute: `.\execute_all_get_endpoints.ps1`
    *   Individual endpoint scripts can also be run directly.

## Development Conventions

*   **File Naming:** Endpoint scripts are named according to the Jira API endpoint they access, and include the HTTP method (e.g., `GET`, `POST`) and the authentication method (e.g., `(Anon)`, `(OAuth2)`).
*   **Code Style:** The PowerShell scripts generally follow a consistent style, with clear headers, comments, and error handling.
*   **Authentication:** As mentioned, the project supports both Basic and OAuth2 authentication. New scripts should be developed with the appropriate authentication method in mind.
*   **Output:** Each endpoint script is designed to output its data to a CSV file in the same directory as the script.
*   **Modularity:** The project is highly modular, with each endpoint script being a self-contained unit. This makes it easy to add new endpoints or modify existing ones.
*   **Documentation:** The project is well-documented, with a detailed `README.md` file, as well as other documentation in the `.docs` directory. Any new development should be accompanied by appropriate documentation.