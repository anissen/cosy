package cosy;

class EditDistance {
    public static function bestMatches(word: String, otherWords: Array<String>, maxEditDistance: Int = 2): Array<String> {
        var minEditDistance = maxEditDistance;
        var bestWords = [];
        for (other in otherWords) {
            var dist = editDistance(word, other);
            // trace('Distance for $word to $other: $dist');
            if (dist < minEditDistance) {
                minEditDistance = dist;
                bestWords = [other];
            } else if (dist == minEditDistance) {
                bestWords.push(other);
            }
        }
        bestWords.sort((a, b) -> (a < b ? -1 : 1));
        return bestWords;
    }

    public static function formatMatches(matches: Array<String>): String {
        if (matches.length == 0) return '';

        var quoted = matches.map(m -> '"$m"');
        var lastMatch = quoted.pop();
        var formattedMatches = (quoted.length > 0 ? quoted.join(', ') + ' or ' + lastMatch : lastMatch);
        return formattedMatches;
    }

    static function editDistance(a: String, b: String): Int {
        // Declaring array 'D' with rows = a.length + 1 and columns = b.length + 1:
        var D = [for (_ in 0...a.length + 1) [for (_ in 0...b.length + 1) 0]];

        // Initialising first row:
        for (i in 0...a.length + 1)
            D[i][0] = i;

        // Initialising first column:
        for (j in 0...b.length + 1)
            D[0][j] = j;

        for (i in 1...a.length + 1) {
            for (j in 1...b.length + 1) {
                if (a.charAt(i - 1) == b.charAt(j - 1)) {
                    D[i][j] = D[i - 1][j - 1];
                } else {
                    // Adding 1 to account for the cost of operation
                    var insertion = 1 + D[i][j - 1];
                    var deletion = 1 + D[i - 1][j];
                    var replacement = 1 + D[i - 1][j - 1];

                    // Choosing the best option:
                    var costs = [insertion, deletion, replacement];
                    costs.sort((a, b) -> a - b);
                    D[i][j] = costs[0];
                }
            }
        }

        return D[a.length][b.length];
    }
}
