### Central ADLSgen2 account connecting to multiple decentral Databricks workspaces
Project that creates a Data lake storage account and connects multiple spoke Databricks workspaces using private link. Storage account and Databricks workspace can live in different subscriptions. The following steps are executed when executing ```scripts/0_run_script.sh```:

- Create 1 ADLSgen2 account and 1 hub VNET. 
- Connect hub VNET and storage account using private link. A private DNS zone is creates as part of the process
- Create N Databricks workspaces in their own worker VNET (spokes). SPN/RBAC/secret scopes are used to access storage account.
- Peer the N Databricks worker VNETs with hub VNET
- Create a private link connection bewteen Databricks worker and DNS private zone

See also overview below (credits to [Marc de Droog](https://www.linkedin.com/in/marc-de-droog-776a94/)):

![Architecture](https://github.com/rebremer/blog-databrickshubspoke-git/blob/main/images/StorhubDatabricksspoke.png)

In case the scripts are successfully rune, Databricks spoke N will be mounted to File sytem N on the central storage account using the private IP address of the storage account, see also screenshot below.

![End result](https://github.com/rebremer/blog-databrickshubspoke-git/blob/main/images/databricks_end_result.png)