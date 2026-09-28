import Foundation

struct ArxivCategory: Identifiable, Hashable {
    let code: String
    let displayName: String
    var id: String { code }
}

struct ArxivArchive: Identifiable {
    let name: String
    let categories: [ArxivCategory]
    var id: String { name }
}

enum ArxivTaxonomy {
    static let archives: [ArxivArchive] = [
        ArxivArchive(name: "Computer Science", categories: [
            ArxivCategory(code: "cs.AI", displayName: "Artificial Intelligence"),
            ArxivCategory(code: "cs.LG", displayName: "Machine Learning"),
            ArxivCategory(code: "cs.CL", displayName: "Computation and Language"),
            ArxivCategory(code: "cs.CV", displayName: "Computer Vision"),
            ArxivCategory(code: "cs.CR", displayName: "Cryptography and Security"),
            ArxivCategory(code: "cs.DC", displayName: "Distributed Computing"),
            ArxivCategory(code: "cs.SE", displayName: "Software Engineering"),
        ]),
        ArxivArchive(name: "Condensed Matter", categories: [
            ArxivCategory(code: "cond-mat.str-el", displayName: "Strongly Correlated Electrons"),
            ArxivCategory(code: "cond-mat.mes-hall", displayName: "Mesoscale and Nanoscale Physics"),
            ArxivCategory(code: "cond-mat.supr-con", displayName: "Superconductivity"),
        ]),
        ArxivArchive(name: "Physics", categories: [
            ArxivCategory(code: "physics.gen-ph", displayName: "General Physics"),
            ArxivCategory(code: "astro-ph.CO", displayName: "Cosmology and Nongalactic Astrophysics"),
            ArxivCategory(code: "quant-ph", displayName: "Quantum Physics"),
        ]),
        ArxivArchive(name: "Mathematics", categories: [
            ArxivCategory(code: "math.CO", displayName: "Combinatorics"),
            ArxivCategory(code: "math.PR", displayName: "Probability"),
            ArxivCategory(code: "math.ST", displayName: "Statistics Theory"),
        ]),
    ]
}
