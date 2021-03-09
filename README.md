### Central ADLSgen2 account connecting multiple decentral Databricks workspaces
Project that creates a Data lake storage account and connects multiple spoke Databricks workspaces. Storage account and Databricks workspace can live in different subscriptions. The following steps are executed:

- Create 1 ADLSgen2 account and 1 hub VNET. 
- Connect hub VNET and storage account using private link. A DNS private zone is creates as part of the process
- Create N Databricks workspaces that are deployed in their own worker VNET (spokes)
- Peer the N Databricks worker VNETs with hub VNET
- Create a private link connection bewteen Databricks worker and DNS private zone

See also overview below (credits to Marc de Droog):

![Architecture](https://github.com/rebremer/blog-databrickshubspoke-git/blob/master/images/StorhubDatabricksspoke.png)
