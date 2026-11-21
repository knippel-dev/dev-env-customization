# Returns $Base with $Override merged over it, without changing either. Nested hashtables are merged
# key by key; any other value in $Override (string, number, array) replaces the one in $Base.
function Merge-Hashtable {
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary]$Base,
        [Collections.IDictionary]$Override
    )
    $result = [ordered]@{}
    foreach ($key in $Base.Keys) { $result[$key] = $Base[$key] }
    if ($Override) {
        foreach ($key in $Override.Keys) {
            $result[$key] = if ($result[$key] -is [Collections.IDictionary] -and $Override[$key] -is [Collections.IDictionary]) {
                Merge-Hashtable $result[$key] $Override[$key]
            }
            else { $Override[$key] }
        }
    }
    $result
}
