# Skipped Endpoints

This file lists Jira Cloud REST API v3 endpoints that were intentionally skipped.

## Reason: Complex Modification/Upload

These endpoints are primarily for modification or involve complex uploads (like image data) that are not well-suited for repeatable Power Query data extraction scripts.

### Avatars

- `POST /rest/api/3/avatar/{type}/temporary` (Load temporary avatar)
- `POST /rest/api/3/avatar/{type}/temporaryCrop` (Crop temporary avatar)
- `DELETE /rest/api/3/avatar/{id}` (Delete avatar)

### Bulk issue property

- `POST /rest/api/3/issue/properties` (Bulk set issue property)
- `DELETE /rest/api/3/issue/properties` (Bulk delete issue property)

### Custom field trash

- `POST /rest/api/3/field/{id}/trash` (Move custom field to trash)
- `POST /rest/api/3/field/{id}/restore` (Restore custom field from trash)

### Dynamic modules

- `GET /rest/api/3/dynamicModules` (Get modules)
- `POST /rest/api/3/dynamicModules` (Register modules)

## Reason: Requires OAuth 2.0 Authentication

These endpoints require a full OAuth 2.0 setup, which is different from the Basic Authentication (API Token) used in the standard templates.

### App Data Policies

- `GET /rest/api/3/data-policy`
- `GET /rest/api/3/data-policy/project`

### App content lifecycle

- `POST /rest/api/3/app/content/restore`
- `POST /rest/api/3/app/content/{id}/export`
- `GET /rest/api/3/app/content/{id}/export/{exportId}`
- `GET /rest/api/3/app/content`
- `DELETE /rest/api/3/app/content`

### App properties

- `DELETE /rest/api/3/app/properties`
- `GET /rest/api/3/app/properties/{propertyKey}`
- `PUT /rest/api/3/app/properties/{propertyKey}`

### Expression evaluation

- `POST /rest/api/3/expression/eval` (Evaluate Jira expression)

### Instance information

- `GET /rest/api/3/instance/license` (Get license)

### Issue security level

- `GET /rest/api/3/issuesecurityschemes/{schemeId}/level` (Get issue security level members)

## Reason: Deprecated

These endpoints are marked as "deprecated" in the official Atlassian documentation and are likely non-functional.

### App Roles

- `GET /rest/api/3/app-role`
- `GET /rest/api/3/app-role/{key}`

### Groups

- `GET /rest/api/3/group` (Get group - functionality is covered by `GET /rest/api/3/group/member`)

### Issue field option

- `GET /rest/api/3/field/{fieldKey}/option` (Get all issue field options)

### Issue type property

- `GET /rest/api/3/issuetype/{issueTypeId}/properties` (Get issue type property keys)
- `PUT /rest/api/3/issuetype/{issueTypeId}/properties/{propertyKey}` (Set issue type property)
- `GET /rest/api/3/issuetype/{issueTypeId}/properties/{propertyKey}` (Get issue type property)
- `DELETE /rest/api/3/issuetype/{issueTypeId}/properties/{propertyKey}` (Delete issue type property)
