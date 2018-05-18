#
# Script jq pour convertir une liste d'issues (demandes) JIRA au format JSON, vers des
# requ�tes SQL en vue d'une insertion en base.
# Au passage on filtrera chaque issue pour n'en retenir que les propri�t�s qui nous int�ressent.
# 
# Version
#    2016.11.29
#
# Utilisation :
#    <liste d'issues au format json comme retourn�e par l'API REST Jira> | jq -r -f jirajson2sql.jq
#
# Exemples :
#    curl -u alexis.grabie:**** -H "Content-Type: application/json" http://localhost:8080/rest/api/2/search | jq -r -f jirajson2sql.jq
#    cat list_issues.json | jq -r -f jirajson2sql.jq
#
# Copyright
#    MAAF


# 1. On commence par un filtrage des propri�t�s des issues...

[
	# Extraction de toutes les issues...
	.issues[] 

	# Pour chaque issue, extraction des champs pertinents...
	# A gauche: cl� de notre choix, � droite, le filtre qui permet de r�cup�rer la valeur
	|
	 {id               : .id, 
	  key              : .key,
	  type             : .fields.issuetype.name,
	  subtask          : .fields.issuetype.subtask,
	  montant_ej       : .fields.customfield_10100,       # pr�sent uniquement dans les t�ches de type "Commande"
	  entite_emettrice : .fields.customfield_10301.value, # id.
	  axe              : .fields.customfield_10201.value, # id.
	  marche           : .fields.customfield_10300.value, # id.
      montant_prevu    : .fields.customfield_10501,       # montant pr�vu     : pour les t�ches de type "Paiement"
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

# A ce stade on a r�cup�r� un tableau JSON d'issues "filtr�" 

# Pour d�buguer : ne travailler que sur un subset d'issues
#| [.[0,1]]

# 2. Transformation en requ�tes sql...
| 
	# Avant d'ins�rer on supprime tout pour �viter d'avoir � g�rer le "UPSERT"  (on ne s'embarrasse pas ...)
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
   
