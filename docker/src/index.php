<?php
require_once 'config.php';

// for failover directing configuration 
$region = $_ENV['AWS_REGION'] ?? 'unknown';
$origin_region = $_SERVER['HTTP_X_ORIGIN_REGION'] ?? 'direct';
$is_failover = ($origin_region === 'eu-west-1');

// Fetch all students
try {
    $stmt = $pdo->query("SELECT * FROM students ORDER BY created_at DESC");
    $students = $stmt->fetchAll(PDO::FETCH_ASSOC);
} catch(PDOException $e) {
    $students = [];
    $error_message = "Error fetching students: " . $e->getMessage();
}

// Handle form submission
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['action'])) {
    if ($_POST['action'] == 'add' && !empty($_POST['name']) && !empty($_POST['age']) && !empty($_POST['department'])) {
        try {
            $stmt = $pdo->prepare("INSERT INTO students (name, age, department) VALUES (?, ?, ?)");
            $stmt->execute([$_POST['name'], (int)$_POST['age'], $_POST['department']]);
            header("Location: " . $_SERVER['PHP_SELF']);
            exit();
        } catch(PDOException $e) {
            $error_message = "Error adding student: " . $e->getMessage();
        }
    } elseif ($_POST['action'] == 'delete' && !empty($_POST['id'])) {
        try {
            $stmt = $pdo->prepare("DELETE FROM students WHERE id = ?");
            $stmt->execute([(int)$_POST['id']]);
            header("Location: " . $_SERVER['PHP_SELF']);
            exit();
        } catch(PDOException $e) {
            $error_message = "Error deleting student: " . $e->getMessage();
        }
    }
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Student Record System - DR Enabled</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body { 
            background-color: #f8f9fa; 
        }
        .header-section { 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white; 
            padding: 3rem 2rem; 
            border-radius: 10px; 
            margin-bottom: 2rem;
        }
        .table { 
            background-color: white; 
            border-radius: 10px; 
            overflow: hidden; 
        }
        .dr-indicator {
            position: absolute;
            top: 10px;
            right: 10px;
            font-size: 0.8rem;
        }
        .dr-indicator.primary {
            background-color: #28a745;
            color: white;
            padding: 5px 10px;
            border-radius: 5px;
        }
        .dr-indicator.dr {
            background-color: #ffc107;
            color: #212529;
            padding: 5px 10px;
            border-radius: 5px;
        }
    </style>
</head>
<body>
    <!-- automatic failover div -->
    <div class="alert alert-info" role="alert">
        <strong>Region:</strong> <?php echo htmlspecialchars($region); ?> 
        <?php if ($is_failover): ?>
            <span class="badge bg-warning">Failover Active</span>
        <?php else: ?>
            <span class="badge bg-success">Normal Operation</span>
        <?php endif; ?>
    </div>

    <div class="container mt-5 position-relative">
        <?php
        // Display region indicator based on environment
        $region = $_ENV['AWS_REGION'] ?? 'unknown';
        $isDR = (strpos($region, 'west') !== false);
        ?>
        <div class="dr-indicator <?php echo $isDR ? 'dr' : 'primary'; ?>">
            Region: <?php echo htmlspecialchars($region); ?> 
            <?php echo $isDR ? '(DR)' : '(Primary)'; ?>
        </div>
        
        <div class="header-section text-center">
            <h1 class="display-4">Student Record System</h1>
            <p class="lead">Containerized LAMP Application on AWS ECS Fargate</p>
            <p class="mb-0">Enterprise-grade with Disaster Recovery</p>
        </div>

        <?php if (isset($error_message)): ?>
            <div class="alert alert-danger alert-dismissible fade show" role="alert">
                <?php echo htmlspecialchars($error_message); ?>
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        <?php endif; ?>

        <!-- Add Student Form -->
        <div class="card mb-4 shadow-sm">
            <div class="card-header bg-primary text-white">
                <h3 class="mb-0">Add New Student</h3>
            </div>
            <div class="card-body">
                <form method="POST" id="addStudentForm">
                    <input type="hidden" name="action" value="add">
                    <div class="row g-3">
                        <div class="col-md-4">
                            <input type="text" class="form-control" name="name" placeholder="Full Name" required 
                                   pattern="[A-Za-z\s]+" title="Please enter a valid name">
                        </div>
                        <div class="col-md-2">
                            <input type="number" class="form-control" name="age" placeholder="Age" 
                                   min="16" max="100" required>
                        </div>
                        <div class="col-md-4">
                            <select class="form-control" name="department" required>
                                <option value="">Select Department</option>
                                <option value="Computer Science">Computer Science</option>
                                <option value="Engineering">Engineering</option>
                                <option value="Business">Business</option>
                                <option value="Medicine">Medicine</option>
                                <option value="Arts">Arts</option>
                            </select>
                        </div>
                        <div class="col-md-2">
                            <button type="submit" class="btn btn-primary w-100">Add Student</button>
                        </div>
                    </div>
                </form>
            </div>
        </div>

        <!-- Students Table -->
        <div class="card shadow-sm">
            <div class="card-header bg-secondary text-white">
                <h3 class="mb-0">All Students (<?php echo count($students); ?> total)</h3>
            </div>
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table table-striped mb-0">
                        <thead class="table-dark">
                            <tr>
                                <th>ID</th>
                                <th>Name</th>
                                <th>Age</th>
                                <th>Department</th>
                                <th>Added On</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($students)): ?>
                                <tr>
                                    <td colspan="6" class="text-center py-4">
                                        <p class="mb-0">No students found. Add your first student!</p>
                                    </td>
                                </tr>
                            <?php else: ?>
                                <?php foreach ($students as $student): ?>
                                    <tr>
                                        <td><?php echo htmlspecialchars($student['id']); ?></td>
                                        <td><?php echo htmlspecialchars($student['name']); ?></td>
                                        <td><?php echo htmlspecialchars($student['age']); ?></td>
                                        <td>
                                            <span class="badge bg-info text-dark">
                                                <?php echo htmlspecialchars($student['department']); ?>
                                            </span>
                                        </td>
                                        <td><?php echo date('M d, Y', strtotime($student['created_at'])); ?></td>
                                        <td>
                                            <form method="POST" style="display:inline;" 
                                                  onsubmit="return confirm('Are you sure you want to delete this student?');">
                                                <input type="hidden" name="action" value="delete">
                                                <input type="hidden" name="id" value="<?php echo $student['id']; ?>">
                                                <button type="submit" class="btn btn-danger btn-sm">Delete</button>
                                            </form>
                                        </td>
                                    </tr>
                                <?php endforeach; ?>
                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
            <div class="card-footer text-muted">
                <small>
                    <?php
                    date_default_timezone_set('UTC');
                    echo "Last updated: " . date('F j, Y, g:i a') . " UTC";
                    ?>
                </small>
            </div>
        </div>
    </div>
    
    <!-- Bootstrap Bundle with Popper -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    
    <!-- Custom JavaScript -->
    <script>
        // Auto-dismiss alerts after 5 seconds
        document.addEventListener('DOMContentLoaded', function() {
            const alerts = document.querySelectorAll('.alert');
            alerts.forEach(function(alert) {
                setTimeout(function() {
                    const bsAlert = new bootstrap.Alert(alert);
                    bsAlert.close();
                }, 5000);
            });
        });
        
        // Form validation
        document.getElementById('addStudentForm').addEventListener('submit', function(e) {
            const name = this.name.value.trim();
            const age = parseInt(this.age.value);
            const department = this.department.value;
            
            if (name.length < 2) {
                alert('Name must be at least 2 characters long');
                e.preventDefault();
                return false;
            }
            
            if (age < 16 || age > 100) {
                alert('Age must be between 16 and 100');
                e.preventDefault();
                return false;
            }
            
            if (!department) {
                alert('Please select a department');
                e.preventDefault();
                return false;
            }
        });
    </script>
</body>
</html>