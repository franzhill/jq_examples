#
# Script jq pour convertir une liste d'issues (demandes) JIRA au format JSON, vers des
# requêtes SQL en vue d'une insertion en base.
# Au passage on filtrera chaque issue pour n'en retenir que les propriétés qui nous intéressent.
# 
# Version
#    2016.11.29
#
# Utilisation :
#    <liste d'issues au format json comme retournée par l'API REST Jira> | jq -r -f jirajson2sql.jq
#
# Exemples :
#    curl -u ******:**** -H "Content-Type: application/json" http://localhost:8080/rest/api/2/search | jq -r -f jirajson2sql.jq
#    cat list_issues.json | jq -r -f jirajson2sql.jq
#
# Copyright
#    MAAF


# 1. On commence par un filtrage des propriétés des issues...

[
	# Extraction de toutes les issues...
	.issues[] 

	# Pour chaque issue, extraction des champs pertinents...
	# A gauche: clé de notre choix, à droite, le filtre qui permet de récupérer la valeur
	|
	 {id               : .id, 
	  key              : .key,
	  type             : .fields.issuetype.name,
	  subtask          : .fields.issuetype.subtask,
	  montant_ej       : .fields.customfield_10100,       # présent uniquement dans les tâches de type X
	  entite_emettrice : .fields.customfield_10301.value, # id.
	  axe              : .fields.customfield_10201.value, # id.
	  marche           : .fields.customfield_10300.value, # id.
	  montant_prevu    : .fields.customfield_10501,       # montant prévu     : pour les tâches de type Y
	  montant_paiement : .fields.customfield_10502,       # montant paiement  : id
	  creator          : .fields.creator.name,
	  created          : .fields.created,
	  description      : .fields.description,
	  parent_id        : .fields.parent.id,
	  parent_key       : .fields.parent.key,
	  parent_summary   : .fields.parent.fields.summary,
	  status           : .fields.status.name
	 }
]

# A ce stade on a récupéré un tableau JSON d'issues "filtré" 

# Pour débuguer : ne travailler que sur un subset d'issues
#| [.[0,1]]

# 2. Transformation en requêtes sql...
| 
	# Avant d'insérer on supprime tout pour éviter d'avoir à gérer le "UPSERT"  (on ne s'embarrasse pas ...)
	(.[0] | "DELETE FROM commande; DELETE FROM paiement;"),

	# Les inserts...
	(.[]  |
		if   .type == "Commande" then 
			"INSERT INTO commande (issue_id, description, creator, created, montant_ej, entite_emettrice, axe, marche, status, jira_url) VALUES ("
				+ "'" + .id                         + "'"  + ", " 
				+ "'" + .description                + "'"  + ", "
				+ "'" + .creator                    + "'"  + ", "
				+ (if .created | length == 0 then "NULL" else  "'" + .created + "'" end)   +  ", "
				+ "'" + (.montant_ej | tostring )   + "'"  + ", "
				+ "'" + .entite_emettrice           + "'"  + ", "
				+ "'" + .axe                        + "'"  + ", "
				+ "'" + .marche                     + "'"  + ", "
				+ "'" + .status                     + "'"  + ", "
				+ "'" + "http://localhost:8080/browse/" + .key  + "'"  
				                                           + "); " 
		elif .type == "Paiement" then
			"INSERT INTO paiement (issue_id, description, creator, created, parent_id, montant_prevu, montant_paiement, status, jira_url) VALUES ("
				+ "'" + .id                            + "'"  +  ", " 
				+ "'" + .description                   + "'"  +  ", "
				+ "'" + .creator                       + "'"  +  ", "
				+ (if .created | length == 0 then "NULL" else  "'" + .created + "'" end)   +  ", "
				+ "'" + .parent_id                     + "'"  +  ", "
				+ "'" + (.montant_prevu   | tostring)  + "'"  +  ", "
				+ "'" + (.montant_paiement| tostring)  + "'"  +  ", "
				+ "'" + .status                        + "'"  +  ", "
				+ "'" + "http://localhost:8080/browse/" + .key  + "'"  
				                                              +  ");" 
		else
			empty
		end
	)
   
