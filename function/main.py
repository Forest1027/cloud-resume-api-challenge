from google.cloud import firestore

def get_resume(request):
    db = firestore.Client()
    doc_ref = db.collection("cloud-resume").document("O4cNUVxSPdArF4uXAy87")
    doc = doc_ref.get()
    if doc.exists:
        return f"Document data: {doc.to_dict()}"
    else:
        return "No such document!"