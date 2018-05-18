#
# Script jq pour convertir une liste d'issues (demandes) JIRA au format JSON, vers le format csv.
# Au passage on filtrera chaque issue pour n'en retenir que les propriétés qui nous intéressent.
# 
# Version
#    2016.11.29
#
# Utilisation :
#    <liste d'issues au format json comme retournée par l'API REST Jira> | jq -f jirajson2csv.jq
#
# Exemples :
#    curl -u user:passwd -H "Content-Type: application/json" http://localhost:8080/rest/api/2/search | jq -r -f jirajson2csv.jq
#    cat list_issues.json | jq -f jirajson2csv.jq
#
# Auteur
#    FHI


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

# Pour débuguer : ne travailler que sur un subset d'issues  (commenter/décommenter)
#  exemple : les 10 premières   
#| [.[0,10]]

# 2. Transformation en csv...

## On aurait pu utiliser : 
## | .[] | [.id, .type] | join(",") 
## mais autant utiliser l'opérateur natif @csv, d'autant qu'avec join on aurait dû visiblement soi-même gérer la conversion des différents types vers du string

# | .[] | [.id, .type, .subtask, .description, .creator, .created, .parent_id, .parent_key] | @csv

# Obtention des libellés des colonnes:
| (map(keys_unsorted))[0] as $cols 

# Débug: afficher...
#| $cols

# Récuperer les lignes (valeurs, dans l'ordre des libellés):
| map(. as $row | $cols | map($row[.])) as $rows 

# Concaténation de la ligne des libellés et des lignes de valeurs et conversion csv :
| $cols, $rows[] | @csv


